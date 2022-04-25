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
my $created_over_time;
my $modified_time;
my $modified_over_time;

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
    plan tests=>5;

    $data = {
        name        => "test style",
    };
    $created_time = DateTime->now;
    $res = $test->request(POST '/style/', $data );
    $created_over_time = DateTime->now;
    ok($res->is_success, 'returned success');
    $decoded = decode_json($res->content);
    $to_test = {};
    foreach my $key (keys %$data){
        $to_test->{$key} = $decoded->{data}{$key};
    };
    is_deeply $to_test, $data, 'return matches';
    cmp_ok strptime('%FT%T', $decoded->{data}{created_ts}), '>=', $created_time, 'created_ts within lower bound';
    cmp_ok strptime('%FT%T', $decoded->{data}{created_ts}), '<=', $created_over_time, 'created_ts within upper bound';
    is $decoded->{data}{created_ts}, $decoded->{data}{modified_ts}, 'created_ts == modified_ts';
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
    $created_time = $decoded->{data}{created_ts}; #for verification in the PUT test
};


subtest 'PUT /style/1' => sub {
    plan tests => 5;

    note 'waiting so that modified_ts != created_ts';
    sleep(1);

    $data = {
        name        => "new name",
    };
    $modified_time = DateTime->now;
    $res = $test->request( PUT '/style/1' , content => $data);
    $modified_over_time = DateTime->now;
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
    foreach my $key (keys %$data){
        $to_test->{$key} = $decoded->{data}{$key};
    };
    is_deeply $to_test, $data, 'GET changed after PUT';
    cmp_ok strptime('%FT%T', $decoded->{data}{modified_ts}), '>=', $modified_time, 'modified_ts within lower bound';
    cmp_ok strptime('%FT%T', $decoded->{data}{modified_ts}), '<=', $modified_over_time, 'modified_ts within upper bound';
};


subtest 'GET /styles' => sub{
    plan tests => 2;

    $res  = $test->request( GET '/styles' );
    ok( $res->is_success, 'Returned success' );
    $data->{style_id} = 1;
    $decoded = decode_json($res->content);
    $to_test = {};
    foreach my $key (keys %$data){
        $to_test->{$key} = $decoded->{data}[0]{$key};
    };
    is_deeply $to_test, $data, 'matches';
};
