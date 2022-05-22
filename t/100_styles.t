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

subtest 'Invalid GET /style/1' => sub{
    plan tests=>2;

    $res = $test->request( GET '/style/1' );
    ok($res->is_success, 'returned success');
    $decoded = decode_json($res->content);
    $expected = {
        errors => [{
            msg => 'Nothing Found for style_id 1',
            num => 1400,
        }]
    };
    is_deeply $decoded, $expected, 'error msg matches';
};

subtest 'POST /style' => sub{
    plan tests=>2;

    $data = {
        name        => "test style",
    };
    $ENV{TEST_NOW} = 1651112285;
    $created_time = get_now();
    $res = $test->request(POST '/style/', $data );
    ok($res->is_success, 'returned success');
    $decoded = decode_json($res->content);
    $to_test = {};
    $data->{created_ts} = $data->{modified_ts} = $created_time;
    foreach my $key (keys %$data){
        $to_test->{$key} = $decoded->{data}{$key};
    };
    is_deeply $to_test, $data, 'return matches';
};


subtest 'GET /style/1' => sub{
    plan tests=>2;

    $res  = $test->request( GET '/style/1' );
    ok( $res->is_success, 'returned success' );
    $decoded = decode_json($res->content); 
    $to_test = {};
    foreach my $key (keys %$data){
        $to_test->{$key} = $decoded->{data}{$key};
    };
    is_deeply $to_test, $data, 'matches';
};


subtest 'PUT /style/1' => sub {
    plan tests => 3;

    $data = {
        name        => "new name",
    };
    $ENV{TEST_NOW} += 100;
    $modified_time = get_now();
    $res = $test->request( PUT '/style/1' , content => $data);
    ok( $res->is_success, 'returned success' );
    $data->{created_ts} = $created_time;
    $decoded = decode_json($res->content);
    $to_test = {};
    foreach my $key (keys %$data){
        $to_test->{$key} = $decoded->{data}{$key};
    };
    is_deeply $to_test, $data, 'return matches';

    $res  = $test->request( GET '/style/1' );
    $decoded = decode_json($res->content); 
    $data->{created_ts} = $created_time;
    $data->{modified_ts} = $modified_time;
    foreach my $key (keys %$data){
        $to_test->{$key} = $decoded->{data}{$key};
    };
    is_deeply $to_test, $data, 'GET changed after PUT';
};


subtest 'GET /styleAll' => sub{
    plan tests => 2;

    $res  = $test->request( GET '/styleAll' );
    ok( $res->is_success, 'Returned success' );
    $data->{style_id} = 1;
    $decoded = decode_json($res->content);
    $to_test = {};
    foreach my $key (keys %$data){
        $to_test->{$key} = $decoded->{data}[0]{$key};
    };
    is_deeply $to_test, $data, 'matches';
};
