package bacds::Scheduler::Route::Event;

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
};

sub get_event() {
    my ($self, $event_id) = @_;

    my $dbh = get_dbh();

    my $event = $dbh->resultset('Event')->find($event_id)
        or return false;

    return event_row_to_result($event);
};

sub post_event() {
    my ($self, $data) = @_;
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
        $event->$column($data->{$column});
    };
    
    $event->series_id(undef) if !$event->series_id;

    $event->insert(); #TODO: check for failure
    #TODO: make it so that we are returning the new data from the db, instead of what was sent.
    return event_row_to_result($event);
    
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
    my ($event) = @_;

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
    };

    foreach my $datetime (qw/start_time end_time created_ts modified_ts/){
        next unless $result->{$datetime};
        $result->{$datetime} = $result->{$datetime}->iso8601;
    };

    return $result;
}

true;
