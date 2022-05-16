package bacds::Scheduler::Model::Event;

use 5.16.0;
use warnings;

use Dancer2;
use Data::Dump qw/dump/;
use DateTime;

use bacds::Scheduler::Util::Db qw/get_dbh/;
use bacds::Scheduler::Util::Time qw/get_now/;

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
};

sub get_event() {
    my ($self, $event_id) = @_;

    my $dbh = get_dbh();

    my $event = $dbh->resultset('Event')->find($event_id)
        or return false;

    my $other_tables = {};
    foreach my $other_table_name (qw/styles/){
        my $rs = $event->$other_table_name;
        $other_tables->{$other_table_name} = $rs->all
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

    # for docs on related tables see DBIx::Class::Relationship::Base
    my @relationships = (
        [qw/Style styles style_id/],
    );
    my $now = get_now();
    my $other_tables = {};
    foreach my $relationship (@relationships){
        my ($other_model, $other_table_name, $primary_key) = @$relationship;

        my $remove = "remove_from_$other_table_name";
        $event->$remove($_) for $event->$other_table_name;

        next unless $incoming_data->{$primary_key};

        my $i = 1;
        my @rs = $dbh->resultset($other_model)->search({
            $primary_key => { '-in' => $incoming_data->{$primary_key} }
        });
        my $add = "add_to_$other_table_name";
        $event->$add($_, {
             ordering => $i++,
             created_ts => $now,
         }) for @rs;
        $other_tables->{$other_table_name} = \@rs;
    }
    
    return event_row_to_result($event, $other_tables);
    
};


sub put_event() {
    my ($self, $data) = @_;
    my $dbh = get_dbh();

    my $resultset = $dbh->resultset('Event')->search(
        { event_id=> { '=' => $data->{event_id} } } # SQL::Abstract::Classic
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
        $event->$column($data->{$column});
    };
    
    $event->series_id(undef) if !$event->series_id;

    $event->update(); #TODO: check for failure
    
    return event_row_to_result($event);

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
                [ map { $_->get_fields_for_event_row } @$other ];
        }
    }

    return $result;
}

true;
