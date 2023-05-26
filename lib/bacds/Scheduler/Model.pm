package bacds::Scheduler::Model;

use 5.16.0;
use warnings;

use Dancer2;
use DateTime;
use Data::Dump qw/dump/;
use Encode qw/is_utf8 encode_utf8/;
use List::Util;
use Scalar::Util qw/blessed/;

use bacds::Scheduler::Util::Db qw/get_dbh/;

=head1 NAME

bacds::Scheduler::Model - Parent class for all Model:: classes

=head1 REQUIREMENTS

In order to successfully inherit from this class, a decendant will
need to implement the following functions

=over 4

=item * get_model_name()

This must return a string that can be sent to C<< dbh->resultset() >>, like C<'Event'>.

=item * get_fields_for_output()

This must return an array of fieldnames that should be included in
result output, like C<qw/name start_date start_time />.

=item * get_fields_for_input()

This must return an array of fieldnames that may be set via POST/PUT,
like C<qw/name start_date start_time />

Make sure not to include any autoindex fields.

=item * get_fkey_fields()

This must return an array of fieldnames that should be set to
C<undef> if POST/PUT is sent anything falsey for them.

=item * get_many_to_manys()

This must return a nested list of lists of other tables with
many-to-many relationships like C<[qw/Style styles style_id/],> With the first
item being the model name (/Models/Style.pm), the second being the tablename in
the database, and the third being the primary key.

=item * get_one_to_manys()

This must return a nested list of lists of other tables with one-to-many
relationships like C<[qw/Style styles style_id style/],> With the first item
being the model name (/Models/Style.pm), the second being the tablename in the
database, the third being the primary key, and the fourth being the singular
form of the tablename (which dbix needs for the way it handles one-to-manys).

=item * get_default_sorting()

This must return a dict that can be sent to C<order_by> in
C<< DBIx::Class::ResultSet->seach() >>

=back

=cut

=head2 get_multiple_rows($args)

Return all rows for this table (or just the ones filtered by $args). Does not
include any information from related tables. Uses get_default_sorting from the
decendent class.

Optional $args can be a hashref  of arguments to DBIx's search() function, e.g.

    { email => 'alice@foo.com' },

Defaults to not showing deleted rows; setting is_deleted = 'dont care' means
show all rows regardless of deleted status

=cut

sub get_multiple_rows {
    my ($class, $args) = @_;
    my $model_name = $class->get_model_name;
    my $dbh = get_dbh();
    my %sorting = $class->get_default_sorting;

    $args->{is_deleted} //= false; #Default to not showing deleted rows
    if ($args->{is_deleted} eq 'dont care'){ #The special string 'dont care' means show all rows regardless of deleted status
        delete $args->{is_deleted};
    }

    my $resultset = $dbh->resultset($model_name)->search(
        $args,
        {
            order_by => \%sorting,
            limit => 1000,
        }
    );

    my @rows;
    while (my $row = $resultset->next) {
        push @rows, $class->_row_to_result($row);
    }

    return \@rows;
}

=head2 get_upcoming_rows

Return all rows from yesterday into the future. Useful for the UI.

=cut

sub get_upcoming_rows {
    my $class = shift;
    my $dbh = get_dbh();

    my $yesterday = DateTime
        ->from_epoch(epoch => ($ENV{TEST_NOW} || time))
        ->subtract(days => 1);

    # see DBIx::Class::Manual::FAQ "format a DateTime object for searching"
    my $dtf = $dbh->storage->datetime_parser;

    my $search_args = {
        start_date => { '>=' => $dtf->format_date($yesterday) }
    };

    return $class->get_multiple_rows($search_args);
}

=head2 get_row($row_id)

Return all information for a single row by primary key. Uses
get_many_to_manys() and get_one_to_manys() from the child class to
include data from related tables.

If nothing found for $row_id returns a bacds::Scheduler::Util::Results object
with the error bits filled in.

=cut

sub get_row {
    my ($class, $row_id) = @_;
    my $model_name = $class->get_model_name;
    my $dbh = get_dbh();

    my $row = $dbh->resultset($model_name)->find($row_id)
        or return $class->not_found_error($row_id);

    my $other_tables = {};

    my @mtms = $class->get_many_to_manys;
    foreach my $mtm (@mtms){
        my ($other_model, $other_table_name, $primary_key) = @$mtm;
        my @others = $row->$other_table_name;
        $other_tables->{$other_table_name} = \@others;
    }

    my @otms = $class->get_one_to_manys;
    foreach my $otm (@otms){
        my ($other_model, $other_table_name, $primary_key, $singular_table_name) = @$otm;
        my @other = $row->$singular_table_name;
        $other_tables->{$other_table_name} = \@other;
    }

    return $class->_row_to_result($row, $other_tables);
}

=head2 post_row()

Insert a new row. Uses get_fields_for_input from the child class to
decide which fields can be set, and get_fkey_fields to know which must
be converted to C<undef>.

On a unique index collision returns a bacds::Scheduler::Util::Results object
from duplicate_row_error with a 409 code.

All these updates are wrapped in a transaction and rolled back if anything
fails.

=cut

sub post_row {
    my ($class, $auditor, %incoming_data) = @_;
    my $model_name = $class->get_model_name;
    $auditor->target($model_name);
    my @fields_for_input = $class->get_fields_for_input;
    my @fkey_fields = $class->get_fkey_fields;
    my $dbh = get_dbh();

    my $row = $dbh->resultset($model_name)->new({});

    foreach my $column (@fields_for_input) {
        my $filtered_input = $class->filter_input($column, $incoming_data{$column});
        $row->$column($filtered_input);
    };

    foreach my $column (@fkey_fields) {
        $row->$column(undef) if !$row->$column;
    };

    #is_deleted shouldn't ever be null, so I'm setting it to 0 if falsey.
    $row->is_deleted(0) if not $row->is_deleted;


    my @pkey = $row->primary_columns;
    my $pkey = $pkey[0]; #We're not using composite pkeys

    # all this is wrapped in a transaction so rolled back if any part fails
    my $inserter = sub {
        eval {
            $row->insert();
            1;
        } or do {
            my ($err) = $@;
            if (my ($msg, $value) = is_duplicate_err($err)) {
                warn "$msg: $value"; # would be nice if we could add signed_in_as?
                return $class->duplicate_row_error($value);
            } else {
                die $err;
            }
        };

        # fetch the row from the db to return so that they're getting the actual
        # results
        my $retrieved_row = $dbh->resultset($model_name)->find($row->$pkey);

        $auditor->target_id($row->$pkey);
        my $audit_name = $retrieved_row->can('synthetic_name')
            ? $retrieved_row->synthetic_name
            : '';
        $audit_name ||= $retrieved_row->can('name')
             ? ' "'.$retrieved_row->name.'"'
             : '';

        $auditor->message(qq{created $model_name$audit_name});

        my $other_tables = $class->_update_relationships($retrieved_row, \%incoming_data, $dbh);

        return $class->_row_to_result($retrieved_row, $other_tables);
    };

    return $dbh->txn_do($inserter);
}

=head2 put_row()

Updates an existing row. Uses get_model_name(),
get_fields_for_input(), and get_fkey_fields from descendent class.

If nothing found for $row_id returns a bacds::Scheduler::Util::Results object
with the error bits filled in.

The multiple table updates in here is wrapped in a transaction.
See https://metacpan.org/dist/DBIx-Class/view/lib/DBIx/Class/Manual/Cookbook.pod#TRANSACTIONS

=cut

sub put_row {
    my ($class, $auditor, %incoming_data) = @_;
    my $model_name = $class->get_model_name;
    $auditor->target($model_name);
    my $dbh = get_dbh();

    my $resultset = $dbh->resultset($model_name);

    my @pkeys = $resultset->result_source->primary_columns;
    my $pkey = $pkeys[0]; #We're not using composite pkeys

    my $row = $resultset->find($incoming_data{$pkey})
        or return $class->not_found_error($incoming_data{$pkey});

    $auditor->target_id($row->$pkey);

    my @fields_for_input = $class->get_fields_for_input;
    foreach my $column (@fields_for_input) {
        next unless exists $incoming_data{$column};
        my $filtered_input = $class->filter_input($column, $incoming_data{$column});
        $auditor->add_update_message($column, $filtered_input)
            if ($row->$column//'') ne $filtered_input;

        $row->$column($filtered_input);
    };

    my @fkey_fields = $class->get_fkey_fields;
    foreach my $column (@fkey_fields) {
        $row->$column(undef) if !$row->$column;
    }

    #is_deleted shouldn't ever be null, so I'm setting it to 0 if falsey.
    $row->is_deleted(0) if not $row->is_deleted;

    # all this is wrapped in a transaction so rolled back if any part fails
    my $updater = sub {
        eval {
            $row->update();
            1;
        } or do {
            my ($err) = $@;
            # Duplicate entry 'Alice Callerton' for key 'caller_id_idx'
            if (my ($msg, $value) = is_duplicate_err($err)) {
                warn "$msg: $value"; # would be nice if we could add signed_in_as?
                return $class->duplicate_row_error($value);
            } else {
                die $err;
            }
        };

        # fetch the row from the db to return so that they're getting the actual
        # results
        my $retrieved_row = $dbh->resultset($model_name)->find($row->$pkey);

        my $other_tables = $class->_update_relationships($retrieved_row, \%incoming_data, $dbh, $auditor);

        return $class->_row_to_result($retrieved_row, $other_tables);
    };

    return $dbh->txn_do($updater);
};

=head2 filter_input($field, $value)

Optional in subclasses, can be used to munge the incoming data to post_row
or put_row.

=cut

sub filter_input {
    my ($class, $field, $value) = @_;
    return $value;
}

sub not_found_error {
    my ($class, $pk) = @_;

    my $model_name = $class->get_model_name;
    my $message = qq{Nothing found for $model_name: primary key "$pk"};

    my $error = bacds::Scheduler::Util::Results->new;
    $error->add_error(404, $message);
    return undef, $error;
}

sub duplicate_row_error {
    my ($class, $value) = @_;

    my $model_name = $class->get_model_name;
    my $message = "There is already an entry for '$value' under $model_name";

    my $error = bacds::Scheduler::Util::Results->new;
    $error->add_error(409, $message); # HTTP 409-Conflict

    return undef, $error;
}

=head2 _row_to_result()

Returns a dict of all applicable information from a row.  Uses
$Fields_For_Output to determine which columns to include.

=cut

sub _row_to_result {
    my ($class, $row, $other_tables) = @_;
    my @fields_for_output = $class->get_fields_for_output;
    my $result = {};

    foreach my $field (@fields_for_output) {
        my $value = $row->$field;
        if (defined blessed($value) && $value->isa('DateTime')) {
            if ($field =~ /_ts$/) { # timestamps get the full thing
                $result->{$field} = $value->iso8601;
            } else { # start_date, end_date just yyyy-mm-dd
                $result->{$field} = $value->ymd('-');
            }
        } elsif ($value && $field =~ /_time$/) { # start_time, end_time change 19:00:00 to 19:00
            $value =~ s/:..$//;
            $result->{$field} = $value;
        } else {
            $result->{$field} = $value;
        }
    };

    my $get_fields_for = "get_fields_for_" . lc $class->get_model_name . "_row";
    if ($other_tables){
        foreach my $other_table_name (keys %$other_tables) {
            my $other = $other_tables->{$other_table_name}
                or next;
            $result->{$other_table_name} =
                ref $other eq 'ARRAY'
                #TODO Why is this sometimes undefined?
                    ?  [ map { $_->$get_fields_for } grep $_, @$other ]
                    : $other->$get_fields_for;
        };
    }

    return $result;
}

=head2 _update_relationships

Clear out the mapping tables for the event, and set them according to
the incoming data.

For docs on related tables see DBIx::Class::Relationship::Base

=cut

sub _update_relationships {
    my ($class, $row, $incoming_data, $dbh, $auditor) = @_;

    my @relationships = $class->get_many_to_manys;
    my $other_tables = {};
    foreach my $relationship (@relationships){
        my ($other_model, $other_table_name, $primary_key) = @$relationship;

        # start by clearing the existing mappings
        my @before = $row->$other_table_name->all;
        my $remove = "remove_from_$other_table_name";
        $row->$remove($_) for $row->$other_table_name;

        my @after;

        if ($incoming_data->{$primary_key}){
            # look up all the objects on the other end of the mappings
            my $i = 1;
            my @rs = $dbh->resultset($other_model)->search({
                $primary_key => { '-in' => $incoming_data->{$primary_key} }
            });

            # add them in one at a time
            my $add = "add_to_$other_table_name";
            $row->$add($_, {
                 ordering => $i++,
             }) for @rs;
            $other_tables->{$other_table_name} = \@rs;
            @after = @rs;
        }
        else{
            $other_tables->{$other_table_name} = [];
        }

        if ($auditor) { # don't bother for create/POST, only update/PUT
            my $before = join ', ', sort map $_->can('name') ? $_->name : $_->$primary_key, @before;
            my $after  = join ', ', sort map $_->can('name') ? $_->name : $_->$primary_key, @after;
            if ($before ne $after) {
                $auditor->add_update_message($other_table_name, $after);
            }
        }
    }

    # one-to-many relationship: there's no mapping table to
    # update, but we need to add the data to $other_tables so
    # that the UI can populate the dropdown
    my @one_to_manys = $class->get_one_to_manys;
    foreach my $relationship (@one_to_manys) {
        my ($other_model, $other_table_name, $primary_key) = @$relationship;
        $other_tables->{$other_table_name} = [];
        if (my $value = $incoming_data->{$primary_key}) {
            if (my @rs = $dbh->resultset($other_model)->search({$primary_key => $value })) {
                $other_tables->{$other_table_name} = \@rs;
            }
        }
    }

    return $other_tables;
}

sub is_duplicate_err {

    if ($_[0] =~ m{
        # mysql
        # Duplicate entry 'Alice Callerton' for key 'caller_id_idx'
        (?<msg>(?-x)Duplicate entry '(?<value>.+?') for key '(?<key_name>.+?'))
        |
        # sqlite (unit tests
        # UNIQUE constraint failed: styles.name [for Statement "INSERT INTO styles ...etc
        (?<msg>(?-x)UNIQUE constraint failed: (?<key_name>[a-z_.]+))
    }x) {
        # TEST_DUP_VALUE: no easy way to get the value out of the sqlite
        # message, so we'll just cheat for the tests and
        my $value = $+{value} // $ENV{TEST_DUP_VALUE};
        if (! $value) {
            if ($0 =~ /\.t$/) {
                $value = 'Set ENV{TEST_DUP_VALUE} in your test if you want something here';
            } else {
                $value = '(value unavailable)'
            }
        };
        return $+{msg}, $value;
    }
    return;
}

1;
