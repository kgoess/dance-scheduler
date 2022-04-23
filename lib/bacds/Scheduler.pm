package bacds::Scheduler;

use 5.16.0;
use warnings;

use Dancer2;
use Data::Dump qw/dump/;
use bacds::Scheduler::Route::Event;

our $VERSION = '0.1';
my $event_model = 'bacds::Scheduler::Route::Event';

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
    my $results = Results->new;
    
    $results->data($event_model->get_events);
    
    return $results->format;
};

get '/event/:event_id' => sub {
    my $event_id = params->{event_id};
    my $results = Results->new;

    my $event = $event_model->get_event($event_id);
    if($event){
        $results->data($event)
    }
    else{
        $results->add_error(100, "Nothing Found for event_id $event_id");
    }

    return $results->format;
};

post '/event/' => sub {
    my $data = {};
    foreach my $field (qw/
        name
        end_time
        start_time
        is_camp
        long_desc
        short_desc
        series_id
        /){
        $data->{$field} = params->{$field};
    };

    my $event = $event_model->post_event($data);
    my $results = Results->new;

    if($event){
        $results->data($event)
    }
    else{
        $results->add_error(200, "Insert failed for new event");
    }

    
    return $results->format;

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

package Results {
    use Dancer2;
    use Class::Accessor::Lite (
        new => 0,
        rw => [ qw(data errors) ],
    );

    sub new {
        return bless {data=>'',errors=>[]};
    }

    sub add_error {
        my ($self, $num, $msg) = @_;
        push @{$self->errors}, {
            msg => $msg,
            num => $num,
        };
    }

    sub format {
        my ($self) = @_;
        return encode_json({
            $self->data ? (data => $self->data) : (),
            $self->errors ? (errors => [
                map { {
                    msg => $_->{msg},
                    num => $_->{num},
                } } @{$self->errors}
            ]) : (),
        });
    }
}

true;
