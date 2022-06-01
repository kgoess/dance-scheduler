package bacds::Scheduler::Model;

use 5.16.0;
use warnings;

use Dancer2;
use DateTime;
use Data::Dump qw/dump/;
use Scalar::Util qw/blessed/;

use bacds::Scheduler::Util::Db qw/get_dbh/;

=head1 NAME

bacds::Scheduler::Model - Parent class for all Model:: classes

=head1 REQUIREMENTS

In order to successfully inherit from this class, a decendant will
need to impliment the following functions

=over 4

=item * get_model_name

This must return a string that can be sent to
C<< dbh->resultset() >>, like C<'Event'>.

=item * get_fields_for_output()

This must return an array of fieldnames that should be included in
result output, like C<qw/name start_time end_time/>.

=item * get_fields_for_input()

This must return an array of fieldnames that may be set via POST/PUT,
like C<qw/name start_time end_time/> 

=item * get_other_table_names()

This must return an array of tablenames that should have their 
relationships checked for single-row output, like C<qw/styles/>.

=item * get_fkey_fields()

This must return an array of fieldnames that should be set to C<undef>
if POST/PUT is sent anything falsey for them.

=item * get_relationships()

This must return a nested list of lists of other tables to update
relationships to, like C<[qw/Style styles style_id/]>

=back

=cut

=head2 get_multiple_rows()

Return all rows for this table. Does not include any information from
related tables.

=cut

sub get_multiple_rows {
    #TODO: This should probably only allow a maximum number of results
    #It should also probably accept args to filter?
    #Or maybe that should be a different function?
    my ($class, $args) = @_;
    my $model_name = $class->get_model_name;
    my $dbh = get_dbh();

    my $resultset = $dbh->resultset($model_name)->search();

    $resultset or die "empty set"; #TODO: More gracefully

    my @rows;

    while (my $row = $resultset->next) {
        push @rows, $class->_row_to_result($row);
    }

    return \@rows;
}

=head2 get_upcoming_rows

Return all rows from yesterday into the future. Useful for the UI.

Still not sure if this needs to be a separate function or just parameters to
get_multiple_rows().

=cut

sub get_upcoming_rows {
    my $class = shift;
    my $dbh = get_dbh();

    my $yesterday = DateTime
        ->from_epoch(epoch => ($ENV{TEST_NOW} || time))
        ->subtract(days => 1);

    # see DBIx::Class::Manual::FAQ "format a DateTime object for searching"
    my $dtf = $dbh->storage->datetime_parser;

    my $model_name = $class->get_model_name;
    my $resultset = $dbh->resultset($model_name)->search({
        start_time => { '>=' => $dtf->format_datetime($yesterday) }
    });

    $resultset or die "empty set"; #TODO: More gracefully

    my @rows;

    while (my $row = $resultset->next) {
        push @rows, $class->_row_to_result($row);
    }

    return \@rows;
}

=head2 get_row()

Return all information for a single row by primary key. Uses
get_other_table_names() from the child class to include data from 
related tables.

=cut

sub get_row {
    my ($class, $row_id) = @_;
    my @other_table_names = $class->get_other_table_names;
    my $model_name = $class->get_model_name;
    my $dbh = get_dbh();

    my $row = $dbh->resultset($model_name)->find($row_id)
        or return false; #TODO: actual error message

    my $other_tables = {};
    foreach my $other_table_name (@other_table_names){
        my @others = $row->$other_table_name;
        $other_tables->{$other_table_name} = \@others;
    }

    return $class->_row_to_result($row, $other_tables);
}

=head2 post_row()

Insert a new row. Uses get_fields_for_input from the child class to
decide which fields can be set, and get_fkey_fields to know which must
be converted to C<undef>.

=cut

sub post_row {
    my ($class, %incoming_data) = @_;
    my $model_name = $class->get_model_name;
    my @fields_for_input = $class->get_fields_for_input;
    my @fkey_fields = $class->get_fkey_fields;
    my $dbh = get_dbh();

    my $row = $dbh->resultset($model_name)->new({});

    foreach my $column (@fields_for_input) {
        $row->$column($incoming_data{$column});
    };

    foreach my $column (@fkey_fields) {
        $row->$column(undef) if !$row->$column;
    };

    $row->insert(); #TODO: check for failure

    my @pkey = $row->primary_columns;
    my $pkey = $pkey[0]; #We're not using composite pkeys
    my $retrieved_row = $dbh->resultset($model_name)->find($row->$pkey);
    # TODO: load a fresh one to be returned
    #     my $millennium_cds_rs = $schema->resultset('CD')->search(
    #    { event_id => $event->event_id },
    #    { prefetch => 'style' }
    #  );

    my $other_tables = $class->_update_relationships($row, \%incoming_data, $dbh);

    return $class->_row_to_result($row, $other_tables);
}

=head2 put_row()

Updates an existing row. Uses get_model_name(), get_fields_for_input(),
and get_fkey_fields from decendent class.

=cut

sub put_row {
    my ($class, %incoming_data) = @_;
    my $dbh = get_dbh();
    my $model_name = $class->get_model_name;

    my $resultset = $dbh->resultset($model_name);

    my @pkeys = $resultset->result_source->primary_columns;
    my $pkey = $pkeys[0]; #We're not using composite pkeys

    $resultset = $resultset->search(
        { $pkey=> { '=' => $incoming_data{$pkey} } } # SQL::Abstract::Classic
    );

    $resultset or return 0; #TODO: More robust error handling

    my $row = $resultset->next; #it's searching on primary key, there will only be 0 or 1 result

    my @fields_for_input = $class->get_fields_for_input;
    foreach my $column (@fields_for_input) {
        $row->$column($incoming_data{$column});
    };

    my @fkey_fields = $class->get_fkey_fields;
    foreach my $column (@fkey_fields) {
        $row->$column(undef) if !$row->$column;
    }

    $row->update(); #TODO: check for failure

    my $other_tables = $class->_update_relationships($row, \%incoming_data, $dbh);

    return $class->_row_to_result($row, $other_tables);
};

=head2 _row_to_result()

Returns a dict of all applicable information from a row.
Uses $Fields_For_Output to determine which columns to include.

=cut

sub _row_to_result {
    my ($class, $row, $other_tables) = @_;
    my @fields_for_output = $class->get_fields_for_output;
    my $result = {};

    foreach my $field (@fields_for_output) {
        my $value = $row->$field;
        if (defined blessed($value) && $value->isa('DateTime')) {
            $result->{$field} = $value->iso8601;
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

Clear out the mapping tables for the event, and set them according to the
incoming data.

For docs on related tables see DBIx::Class::Relationship::Base

=cut

sub _update_relationships {
    my ($class, $row, $incoming_data, $dbh) = @_;

    my @relationships = $class->get_relationships;
    my $other_tables = {};
    foreach my $relationship (@relationships){
        my ($other_model, $other_table_name, $primary_key) = @$relationship;

        # start by clearing the existing mappings
        my $remove = "remove_from_$other_table_name";
        $row->$remove($_) for $row->$other_table_name;

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
        }
        else{
            $other_tables->{$other_table_name} = [];
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

1;
