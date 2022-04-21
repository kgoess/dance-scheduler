package bacds::Scheduler;

use 5.16.0;
use warnings;

use Dancer2;
use Data::Dump qw/dump/;
use DateTime;

use bacds::Scheduler::Schema;

our $VERSION = '0.1';

get '/' => sub {

    template 'index' => {
        title => 'Dance Schedule',
        stuff =>'does this work',
        accordions => [
            { label => 'Events',
              content => template("events.tt", {}, { layout=> undef }),
            },
            { label => 'something else',
              content => template("accordion2.tt", {}, { layout=> undef }),
            },
        ],

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

    return encode_json {data => \@events};
};

get '/event/:event_id' => sub {
    my $event_id = params->{event_id};

    my $dbh = get_dbh();

    my $event = $dbh->resultset('Event')->find($event_id)
        or return encode_json {
            error => "Nothing Found for event_id $event_id",
            errornum => 100
        };

    return encode_json {data => event_row_to_json($event)};
};

post '/event/' => sub {
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


    my $event = $dbh->resultset('Event')->new({});

    foreach my $column (@columns){
        $event->$column(params->{$column});
    };
    
    $event->series_id(undef) if !$event->series_id;
    $event->modified_ts(DateTime->now);
    $event->created_ts(DateTime->now);


    $event->insert(); #TODO: check for failure?
    
    return encode_json {data => event_row_to_json($event)};

};

put '/event/:event_id' => sub {
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
    
    $event->series_id(undef) if !$event->series_id;
    $event->modified_ts(DateTime->now);

    $event->update(); #TODO: check for failure?
    
    return encode_json {data => event_row_to_json($event)};

};

sub get_dbh {
    my $database = 'schedule';
    my $hostname = 'localhost';
    my $port = 3306;
    my $password = `cat ~/.mysql-password`;
    chomp $password;
    my $user = 'scheduler';
    my %dbi_params = ();

    my $dbi_dsn = $ENV{TEST_DSN} || "DBI:mysql:database=$database;host=$hostname;port=$port";

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
