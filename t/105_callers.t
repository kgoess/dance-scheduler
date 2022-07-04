use 5.16.0;
use warnings;

use Data::Dump qw/dump/;
use DateTime::Format::Strptime qw/strptime/;
use DateTime;
use HTTP::Request::Common;
use JSON::MaybeXS qw/decode_json/;
use Plack::Test;
use Ref::Util qw/is_coderef/;
use Test::Differences qw/eq_or_diff/;
use Test::More tests => 5;

use bacds::Scheduler;
use bacds::Scheduler::Schema;
use bacds::Scheduler::Util::Time qw/get_now/;
use bacds::Scheduler::Util::Db qw/get_dbh/;

use bacds::Scheduler::Util::TestDb qw/setup_test_db/;
setup_test_db;

my $app = bacds::Scheduler->to_app;
my $test = Plack::Test->create($app);
my $dbh = get_dbh();

my $Caller;
my $Caller_Id;
my $Created_Time;
my $Modified_Time;


subtest 'Invalid GET /caller/1' => sub{
    plan tests=>2;

    my ($res, $decoded, $got, $expected);
    $res = $test->request( GET '/caller/1' );
    ok($res->is_success, 'returned success');

    $decoded = decode_json($res->content);
    $expected = {
        data => '',
        errors => [{
            msg => 'Nothing Found for caller_id 1',
            num => 2900,
        }]
    };
    eq_or_diff $decoded, $expected, 'error msg matches';
};

subtest 'POST /caller' => sub{
    plan tests=>2;

    my ($expected, $res, $decoded, $got);
    my $new_caller = {
        name        => "test caller",
        caller_id   => '', # the webapp sends name=test+caller&caller_id=
    };
    $ENV{TEST_NOW} = 1651112285;
    $Created_Time = get_now()->iso8601;
    $res = $test->request(POST '/caller/', $new_caller );
    ok($res->is_success, 'returned success');

    $decoded = decode_json($res->content);
    $got = $decoded->{data};
    $expected = {
        caller_id    => 1,
        name        => $new_caller->{name},
        created_ts  => $Created_Time,
        modified_ts => $Created_Time,
        is_deleted  => 0,
    };
    eq_or_diff $got, $expected, 'return matches';

    # now save it for the subsequent tests
    $Caller = $dbh->resultset('Caller')->find($decoded->{data}{caller_id});
    $Caller_Id = $Caller->caller_id;
};


subtest 'GET /caller/#' => sub{
    plan tests=>2;

    my ($res, $decoded, $got, $expected);

    $res  = $test->request( GET "/caller/$Caller_Id" );
    ok( $res->is_success, 'returned success' );

    $decoded = decode_json($res->content); 
    $got = $decoded->{data};
    $expected = {
        caller_id    => $Caller_Id,
        name        => $Caller->name,
        created_ts  => $Created_Time,
        modified_ts => $Created_Time,
        is_deleted  => 0,
    };
    eq_or_diff $got, $expected, 'return matches';
};


subtest 'PUT /caller/#' => sub {
    plan tests => 3;

    my ($res, $decoded, $got, $expected);
    my $edit_caller = {
        name        => "new name",
    };
    $ENV{TEST_NOW} += 100;
    $Modified_Time = get_now()->iso8601;
    $res = $test->request( PUT "/caller/$Caller_Id" , content => $edit_caller);
    ok( $res->is_success, 'returned success' );
    
    $decoded = decode_json($res->content);
    $got = $decoded->{data};
    $expected = {
        caller_id    => $Caller_Id,
        name        => $edit_caller->{name},
        created_ts  => $Created_Time,
        modified_ts => $Modified_Time,
        is_deleted  => 0,
    };
    eq_or_diff $got, $expected, 'return matches';

    $res  = $test->request( GET "/caller/$Caller_Id" );
    $decoded = decode_json($res->content); 
    $got = $decoded->{data};
    eq_or_diff $got, $expected, 'GET changed after PUT';

    # update our global caller object
    $Caller = $dbh->resultset('Caller')->find($Caller_Id);
};


subtest 'GET /callerAll' => sub{
    plan tests => 2;

    my ($res, $decoded, $got, $expected);
    $res  = $test->request( GET '/callerAll' );
    ok( $res->is_success, 'Returned success' );

    $decoded = decode_json($res->content);
    $got = $decoded->{data};
    $expected = [
      {
        caller_id    => $Caller_Id,
        name        => $Caller->name,
        created_ts  => $Created_Time,
        modified_ts => $Modified_Time,
        is_deleted  => 0,
      },
    ];
    eq_or_diff $got, $expected, 'matches';
};
