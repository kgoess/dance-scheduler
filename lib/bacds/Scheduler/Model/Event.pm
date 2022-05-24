package bacds::Scheduler::Model::Event;

use 5.16.0;
use warnings;

use Dancer2;
use Data::Dump qw/dump/;
use DateTime;

use bacds::Scheduler::Util::Db qw/get_dbh/;

sub get_events {
    #TODO: This should probably only allow a maximum number of results
    #It should also probably accept args to filter?
    #Or maybe that should be a different function?
    my $dbh = get_dbh();

    my $resultset = $dbh->resultset('Event')->search();

    $resultset or die "empty set"; #TODO: More gracefully

    my @events;

    while (my $event = $resultset->next) {
        push @events, event_row_to_result($event);
    }

    return \@events;
}

=head2 get_upcoming_events

Return all events from yesterday into the future. Useful for the UI.

Still not sure if this needs to be a separate function or just parameters to
get_events.

=cut

sub get_upcoming_events {
    my $dbh = get_dbh();

    my $yesterday = DateTime
        ->from_epoch(epoch => ($ENV{TEST_NOW} || time))
        ->subtract(days => 1);

    # see DBIx::Class::Manual::FAQ "format a DateTime object for searching"
    my $dtf = $dbh->storage->datetime_parser;

    my $resultset = $dbh->resultset('Event')->search({
        start_time => { '>=' => $dtf->format_datetime($yesterday) }
    });

    $resultset or die "empty set"; #TODO: More gracefully

    my @events;

    while (my $event = $resultset->next) {
        push @events, event_row_to_result($event);
    }

    return \@events;
}

sub get_event {
    my ($self, $event_id) = @_;

    my $dbh = get_dbh();

    my $event = $dbh->resultset('Event')->find($event_id)
        or return false;

    my $other_tables = {};
    foreach my $other_table_name (qw/styles/){
        my @others = $event->$other_table_name;
        $other_tables->{$other_table_name} = \@others;
    }

    return event_row_to_result($event, $other_tables);
};

sub post_event() {
    my ($self, $incoming_data) = @_;
    my $dbh = get_dbh();

    my $event = $dbh->resultset('Event')->new({});

    foreach my $column (qw/
        name
        end_time
        start_time
        is_camp
        long_desc
        short_desc
        series_id
        /){
        $event->$column($incoming_data->{$column});
    };

    $event->series_id(undef) if !$event->series_id;

    $event->insert(); #TODO: check for failure

    my $retrieved_event = $dbh->resultset('Event')->find($event->event_id);
    # TODO: load a fresh one to be returned
    #     my $millennium_cds_rs = $schema->resultset('CD')->search(
    #    { event_id => $event->event_id },
    #    { prefetch => 'style' }
    #  );

    my $other_tables = $self->update_relationships($event, $incoming_data, $dbh);

    return event_row_to_result($event, $other_tables);
}

=head2 update_relationships

Clear out the mapping tables for the event, and set them according to the
incoming data.

For docs on related tables see DBIx::Class::Relationship::Base
=cut

sub update_relationships {
    my ($self, $event, $incoming_data, $dbh) = @_;

    my @relationships = (
        [qw/Style styles style_id/],
    );
    my $other_tables = {};
    foreach my $relationship (@relationships){
        my ($other_model, $other_table_name, $primary_key) = @$relationship;

        # start by clearing the existing mappings
        my $remove = "remove_from_$other_table_name";
        $event->$remove($_) for $event->$other_table_name;

        if ($incoming_data->{$primary_key}){
            # look up all the objects on the other end of the mappings
            my $i = 1;
            my @rs = $dbh->resultset($other_model)->search({
                $primary_key => { '-in' => $incoming_data->{$primary_key} }
            });

            # add them in one at a time
            my $add = "add_to_$other_table_name";
            $event->$add($_, {
                 ordering => $i++,
             }) for @rs;
            $other_tables->{$other_table_name} = \@rs;
        }
        else{
            $other_tables->{$other_table_name} = [];
        }
    }

    return $other_tables;
}

sub put_event {
    my ($self, $incoming_data) = @_;
    my $dbh = get_dbh();

    my $resultset = $dbh->resultset('Event')->search(
        { event_id=> { '=' => $incoming_data->{event_id} } } # SQL::Abstract::Classic
    );

    $resultset or return 0; #TODO: More robust error handling

    my $event = $resultset->next; #it's searching on primary key, there will only be 0 or 1 result

    foreach my $column (qw/
        name
        end_time
        start_time
        is_camp
        long_desc
        short_desc
        series_id
        /){
        $event->$column($incoming_data->{$column});
    };

    $event->series_id(undef) if !$event->series_id;

    $event->update(); #TODO: check for failure

    my $other_tables = $self->update_relationships($event, $incoming_data, $dbh);

    return event_row_to_result($event, $other_tables);
};


sub event_row_to_result {
    my ($event, $other_tables) = @_;

    my $result = {};

    foreach my $field (qw/
        event_id
        name
        start_time
        end_time
        is_camp
        long_desc
        short_desc
        is_template
        series_id
        created_ts
        modified_ts/){
        $result->{$field} = $event->$field;
    }

    foreach my $datetime (qw/start_time end_time created_ts modified_ts/){
        next unless $result->{$datetime};
        $result->{$datetime} = $result->{$datetime}->iso8601;
    }

    if ($other_tables){
        foreach my $other_table_name (keys %$other_tables){
            my $other = $other_tables->{$other_table_name}
                or next;
            $result->{$other_table_name} =
                ref $other eq 'ARRAY'
                    ?  [ map { $_->get_fields_for_event_row } @$other ]
                    : $other->get_fields_for_event_row;
        }
    }

    return $result;
}

true;
