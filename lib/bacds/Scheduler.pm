package bacds::Scheduler;

use 5.16.0;
use warnings;

use Dancer2;
use Data::Dump qw/dump/;

use bacds::Scheduler::Schema;

our $VERSION = '0.1';

get '/' => sub {

    template 'index' => {
        title => 'Dance Schedule',
        stuff =>'does this work',
    };
};

get '/events' => sub {

    my $dbh = get_dbh();

    my $resultset = $dbh->resultset('Event')->search();

    $resultset or die "empty set"; #TODO: More gracefully

    my @events;

    while (my $event = $resultset->next) {
        push @events, event_row_to_json($event);
    }

    return encode_json \@events;
};

get '/event/:event_id' => sub {
    my $event_id = params->{event_id};

    my $dbh = get_dbh();

    my $resultset = $dbh->resultset('Event')->search(
        { event_id=> { '=' => $event_id } } # SQL::Abstract::Classic
    );

    $resultset or die "empty set"; #TODO: More gracefully

    my $event = $resultset->next; #it's searching on primary key, there will only be 0 or 1 result
    
    return encode_json event_row_to_json($event);
};

post '/event/:event_id' => sub {
    my $event_id = params->{event_id};
    my $dbh = get_dbh();

    my @columns = qw(
        name
        end_time
        start_time
        is_camp
        long_desc
        short_desc
        event_type
        series_id
        );


    my $resultset = $dbh->resultset('Event')->search(
        { event_id=> { '=' => $event_id } } # SQL::Abstract::Classic
    );

    $resultset or die "empty set"; #TODO: More gracefully

    my $event = $resultset->next; #it's searching on primary key, there will only be 0 or 1 result

    foreach my $column (@columns){
        $event->$column(params->{$column});
    };
    
    $event->modified_ts(time());

    $event->update(); #TODO: check for failure?
    
    return 1;

};

sub get_dbh {
    my $database = 'schedule';
    my $hostname = 'localhost';
    my $port = 3306;
    my $password = `cat ~/.mysql-password`;
    chomp $password;
    my $user = 'scheduler';
    my %dbi_params = ();

    my $dbi_dsn = "DBI:mysql:database=$database;host=$hostname;port=$port";

    my $dbh = bacds::Scheduler::Schema->connect($dbi_dsn, $user, $password, \%dbi_params)
        or die "can't connect"; #TODO: More gracefully

    return $dbh;
}

sub event_row_to_json {
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
        event_type
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
