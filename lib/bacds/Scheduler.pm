package bacds::Scheduler;
use Dancer2;
use Data::Dump qw/dump/;

our $VERSION = '0.1';

get '/' => sub {
    template 'index' => { 'title' => 'Dance Schedule', 'stuff'=>'does this work' };
};
get '/event/:event_id' => sub {
    my $event_id = params->{event_id};

    use bacds::Scheduler::Schema;

    my $database = 'schedule';
    my $hostname = 'localhost';
    my $port = 3306;
    my $password = `cat ~/.mysql-password`;
    chomp $password;
    my $user = 'scheduler';
    my %dbi_params = ();

    my $dbi_dsn = "DBI:mysql:database=$database;host=$hostname;port=$port";

    my $schema = bacds::Scheduler::Schema->connect($dbi_dsn, $user, $password, \%dbi_params)
        or die "can't connect";

    my $resultset = $schema->resultset('Event')->search(
        { event_id=> { '=' => $event_id } } # SQL::Abstract::Classic
    );

    $resultset or die "empty set";

    my $event = $resultset->next; #it's searching on primary key, there will only be 0 or 1 result
    

    my $result;
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
        $result->{$datetime} = $result->{$datetime}->iso8601;
    };
    return encode_json $result;
};


true;
