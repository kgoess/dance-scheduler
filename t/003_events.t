use 5.16.0;
use warnings;
use JSON qw/decode_json/;
use Data::Dump qw/dump/;

use bacds::Scheduler;
use bacds::Scheduler::Schema;
use Test::More tests => 5;
use Plack::Test;
use HTTP::Request::Common;
use Ref::Util qw/is_coderef/;
use URL::Encode qw/url_encode/;
use DateTime;

unlink "testdb";

$ENV{TEST_DSN} = 'dbi:SQLite:dbname=testdb';
# load an on-disk test database and deploy the required tables
bacds::Scheduler::Schema->connection($ENV{TEST_DSN},'','');
bacds::Scheduler::Schema->load_namespaces;
bacds::Scheduler::Schema->deploy;

my $app = bacds::Scheduler->to_app;

my $test = Plack::Test->create($app);
my $res;
my $decoded; 
my $expected;
my $data;
my $to_test;
my $insert_ts;
my $modified_ts;

subtest 'Invalid GET' => sub{
    plan tests=>2;
    $res = $test->request( GET '/event/1' );
    ok($res->is_success, 'returned success');
    $decoded = decode_json($res->content);
    $expected = {
        errors => [{
            msg => 'Nothing Found for event_id 1',
            num => 1100,
        }]
    };
    is_deeply $decoded, $expected, 'error msg matches' or diag explain $decoded;
};

subtest 'POST' => sub{
    plan tests=>2;
    $data = {
        start_time  => "2022-05-01T20:00:00",
        end_time    => "2022-05-01T22:00:00",
        is_camp     => 1,
        long_desc   => "this is the long desc",
        name        => "saturday night test event",
        series_id   => undef,
        short_desc  => "itsa shortdesc",
    };
    $insert_ts = DateTime->now->iso8601;
    #TODO This can be off by a second if the process occurs at the right(wrong) time.
    $res = $test->request(POST '/event/', $data );
    ok($res->is_success, 'returned success');
    $decoded = decode_json($res->content);
    $to_test = {};
    $data->{created_ts} = $insert_ts;
    $data->{modified_ts} = $insert_ts;
    foreach my $key (keys %$data){
        $to_test->{$key} = $decoded->{data}{$key};
    };
    is_deeply $to_test, $data, 'return matches' or diag explain $decoded;
};


subtest 'GET /event/1' => sub{
    plan tests=>2;
    $res  = $test->request( GET '/event/1' );
    ok( $res->is_success, 'returned success' );
    $decoded = decode_json($res->content); 
    $to_test = {};
    foreach my $key (keys %$data){
        $to_test->{$key} = $decoded->{data}{$key};
    };
    is_deeply $to_test, $data, 'matches' or diag explain $decoded;
};


subtest 'PUT' => sub {
    plan tests => 3;

    $data = {
        start_time  => "2022-05-01T21:00:00",
        end_time    => "2022-05-01T23:00:00",
        is_camp     => 0,
        long_desc   => "this is a new long desc",
        name        => "new name",
        short_desc  => "new shortdef",
    };
    $modified_ts = DateTime->now->iso8601;
    #TODO This can be off by a second if the process occurs at the right(wrong) time.
    $res = $test->request( PUT '/event/1' , content => $data);
    ok( $res->is_success, 'returned success' );
    $data->{created_ts} = $insert_ts;
    $data->{modified_ts} = $modified_ts;
    $decoded = decode_json($res->content);
    $to_test = {};
    foreach my $key (keys %$data){
        $to_test->{$key} = $decoded->{data}{$key};
    };
    is_deeply $to_test, $data, 'return matches' or diag explain $decoded;

    $res  = $test->request( GET '/event/1' );
    $decoded = decode_json($res->content); 
    foreach my $key (keys %$data){
        $to_test->{$key} = $decoded->{data}{$key};
    };
    is_deeply $to_test, $data, 'GET changed after PUT' or diag explain $decoded;
};


subtest 'GET /events' => sub{
    plan tests => 2;
    $res  = $test->request( GET '/events' );
    ok( $res->is_success, 'Returned success' );
    $data->{event_id} = 1;
    $decoded = decode_json($res->content);
    $to_test = {};
    foreach my $key (keys %$data){
        $to_test->{$key} = $decoded->{data}[0]{$key};
    };
    is_deeply $to_test, $data, 'matches' or diag explain $decoded;
};
