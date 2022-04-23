use 5.16.0;
use warnings;
use JSON qw/decode_json/;
use Data::Dump qw/dump/;

use bacds::Scheduler;
use bacds::Scheduler::Schema;
use Test::More tests => 24;
use Plack::Test;
use HTTP::Request::Common;
use Ref::Util qw/is_coderef/;
use URL::Encode qw/url_encode/;

unlink "testdb";

$ENV{TEST_DSN} = 'dbi:SQLite:dbname=testdb';
# load an in-memory database and deploy the required tables
bacds::Scheduler::Schema->connection($ENV{TEST_DSN},'','');
bacds::Scheduler::Schema->load_namespaces;
bacds::Scheduler::Schema->deploy;

my $app = bacds::Scheduler->to_app;

my $test = Plack::Test->create($app);
my $res;
my $decoded; 
my $expected;
my $data;

$res = $test->request( GET '/event/1' );
ok($res->is_success, '[GET /event/1] for no id match');
$decoded = decode_json($res->content);
$expected = {
    errors => [{
        msg => 'Nothing Found for event_id 1',
        num => 100,
    }]
};
is_deeply $decoded, $expected, '[GET /event/1] error msg' or diag explain $decoded;

$data = {
  end_time    => "2022-05-01T22:00:00",
  event_id    => 1,
  is_camp     => 1,
  long_desc   => "this is the long desc",
  name        => "saturday night test event",
  series_id   => undef,
  short_desc  => "itsa shortdesc",
  start_time  => "2022-05-01T20:00:00",
  };
$res = $test->request(POST '/event/', $data );
ok($res->is_success, '[POST /event/]');
$decoded = decode_json($res->content);
is $decoded->{data}{long_desc}, $data->{long_desc}, '[POST /event/] long_desc' or diag explain $decoded;

$res  = $test->request( GET '/event/1' );
ok( $res->is_success, '[GET /event/1]' );
$decoded = decode_json($res->content); 
foreach my $key (sort keys %$data){
    is $decoded->{data}{$key}, $data->{$key}, "Checking $key" or diag explain $decoded;
};

$data = {
    end_time    => "2022-05-01T22:00:00",
    event_id    => 1,
    is_camp     => 1,
    long_desc   => "this is the long desc",
    name        => "saturday night test event",
    series_id   => undef,
    short_desc  => "itsa shortdesc",
    start_time  => "2022-05-01T20:00:00",
};
$res = $test->request( PUT '/event/1' , content => $data);
ok( $res->is_success, '[PUT /event/1] ' );
my $dbh = bacds::Scheduler->get_dbh();
my $resultset = $dbh->resultset('Event')->search(
    { event_id=> { '=' => 1 } } # SQL::Abstract::Classic
);
$resultset or die "empty set"; #TODO: More gracefully
my $event = $resultset->next; #it's searching on primary key, there will only be 0 or 1 result
is $event->is_camp, 1, '[PUT /event/1] changes is_camp ';


$data = {
    end_time    => "2022-05-01T22:00:00",
    event_id    => 1,
    is_camp     => 1,
    long_desc   => "this is the long desc",
    name        => "saturday night test event",
    series_id   => undef,
    short_desc  => "itsa shortdesc",
    start_time  => "2022-05-01T20:00:00",
};
$res  = $test->request( GET '/events' );
ok( $res->is_success, '[GET /events] ' );
$decoded = decode_json($res->content);
foreach my $event (@{$decoded->{data}}){
    foreach my $key (sort keys %$data){
        is $event->{$key}, $data->{$key}, "Checking $key" or diag explain $event;
    }
}
