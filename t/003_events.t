use 5.16.0;
use warnings;
use JSON qw/decode_json/;
use Data::Dump qw/dump/;

use bacds::Scheduler;
use bacds::Scheduler::Schema;
use bacds::Scheduler::Util::Time qw/get_now/;
use Test::More tests => 5;
use Plack::Test;
use HTTP::Request::Common;
use Ref::Util qw/is_coderef/;
use URL::Encode qw/url_encode/;
use DateTime;
use DateTime::Format::Strptime qw/strptime/;

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
my $created_time;
my $modified_time;

subtest 'Invalid GET /event/1' => sub{
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
    is_deeply $decoded, $expected, 'error msg matches';
};

subtest 'POST /event' => sub{
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
    $ENV{TEST_NOW} = 1651112285;
    $created_time = get_now();
    $res = $test->request(POST '/event/', $data );
    ok($res->is_success, 'returned success');
    $decoded = decode_json($res->content);
    $to_test = {};
    $data->{created_ts} = $data->{modified_ts} = $created_time;
    foreach my $key (keys %$data){
        $to_test->{$key} = $decoded->{data}{$key};
    };
    is_deeply $to_test, $data, 'return matches';
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
    is_deeply $to_test, $data, 'matches';
};


subtest 'PUT /event/1' => sub {
    plan tests => 3;

    $data = {
        start_time  => "2022-05-01T21:00:00",
        end_time    => "2022-05-01T23:00:00",
        is_camp     => 0,
        long_desc   => "this is a new long desc",
        name        => "new name",
        short_desc  => "new shortdef",
    };
    $ENV{TEST_NOW} += 100;
    $modified_time = get_now();
    $res = $test->request( PUT '/event/1' , content => $data);
    $data->{created_ts} = $created_time;
    ok( $res->is_success, 'returned success' );
    $decoded = decode_json($res->content);
    $to_test = {};
    foreach my $key (keys %$data){
        $to_test->{$key} = $decoded->{data}{$key};
    };
    is_deeply $to_test, $data, 'return matches';

    $res  = $test->request( GET '/event/1' );
    $decoded = decode_json($res->content); 
    $data->{created_ts} = $created_time;
    $data->{modified_ts} = $modified_time;
    foreach my $key (keys %$data){
        $to_test->{$key} = $decoded->{data}{$key};
    };
    is_deeply $to_test, $data, 'GET changed after PUT';
};

# *******Now adding styles *******


my $style_id;
subtest 'POST /event with styles' => sub{
    plan tests=>4;

    $data = {
        name        => "test style",
    };
    $res = $test->request(POST '/style/', $data );
    ok($res->is_success, 'created style');
    $decoded = decode_json($res->content);
    $style_id = $decoded->{data}{style_id};
    $to_test = {};
    foreach my $key (keys %$data){
        $to_test->{$key} = $decoded->{data}{$key};
    };
    is_deeply $to_test, $data, 'style return matches';


    $data = {
        start_time  => "2022-05-01T20:00:00",
        end_time    => "2022-05-01T22:00:00",
        is_camp     => 1,
        long_desc   => "this is the long desc",
        name        => "saturday night test event",
        series_id   => undef,
        short_desc  => "itsa shortdesc",
        style_id   => [$style_id],
    };
    $ENV{TEST_NOW} = 1651112285;
    $created_time = get_now();
    $res = $test->request(POST '/event/', $data );
    ok($res->is_success, 'returned success');
    $decoded = decode_json($res->content);
    $to_test = {};
    $data->{created_ts} = $data->{modified_ts} = $created_time;
    foreach my $key (keys %$data){
        $to_test->{$key} = $decoded->{data}{$key};
    };
    is_deeply $to_test, $data, 'return matches' or dump($decoded);
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
    is_deeply $to_test, $data, 'matches';
};


subtest 'PUT /event/1' => sub {
    plan tests => 3;

    $data = {
        start_time  => "2022-05-01T21:00:00",
        end_time    => "2022-05-01T23:00:00",
        is_camp     => 0,
        long_desc   => "this is a new long desc",
        name        => "new name",
        short_desc  => "new shortdef",
    };
    $ENV{TEST_NOW} += 100;
    $modified_time = get_now();
    $res = $test->request( PUT '/event/1' , content => $data);
    $data->{created_ts} = $created_time;
    ok( $res->is_success, 'returned success' );
    $decoded = decode_json($res->content);
    $to_test = {};
    foreach my $key (keys %$data){
        $to_test->{$key} = $decoded->{data}{$key};
    };
    is_deeply $to_test, $data, 'return matches';

    $res  = $test->request( GET '/event/1' );
    $decoded = decode_json($res->content); 
    $data->{created_ts} = $created_time;
    $data->{modified_ts} = $modified_time;
    foreach my $key (keys %$data){
        $to_test->{$key} = $decoded->{data}{$key};
    };
    is_deeply $to_test, $data, 'GET changed after PUT';
};

subtest 'GET /eventAll' => sub{
    plan tests => 2;

    $res  = $test->request( GET '/eventAll' );
    ok( $res->is_success, 'Returned success' );
    $data->{event_id} = 1;
    $decoded = decode_json($res->content);
    $to_test = {};
    foreach my $key (keys %$data){
        $to_test->{$key} = $decoded->{data}[0]{$key};
    };
    is_deeply $to_test, $data, 'matches';
};
