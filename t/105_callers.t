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
use Test::More tests => 6;
use Test::Warn;

use bacds::Scheduler;
use bacds::Scheduler::Schema;
use bacds::Scheduler::Util::Time qw/get_now/;
use bacds::Scheduler::Util::Db qw/get_dbh/;

use bacds::Scheduler::Util::Test qw/setup_test_db get_tester/;
setup_test_db;

my $app = bacds::Scheduler->to_app;
my $test = get_tester(auth => 1);
my $dbh = get_dbh();

my $Caller;
my $Caller_Id;
my $Created_Time;
my $Modified_Time;


subtest 'Invalid GET /caller/1' => sub {
    plan tests => 2;

    my ($res, $decoded, $got, $expected);
    $res = $test->request( GET '/caller/1' );
    ok($res->is_success, 'returned success');

    $decoded = decode_json($res->content);
    $expected = {
        data => '',
        errors => [{
            msg => 'Nothing found for Caller: primary key "1"',
            num => 404,
        }]
    };
    eq_or_diff $decoded, $expected, 'error msg matches';
};

subtest 'POST /caller' => sub {
    plan tests=>2;

    my ($expected, $res, $decoded, $got);
    my $new_caller = {
        name        => "test caller",
        url         => "http://caller2-url",
        caller_id   => '', # the webapp sends name=test+caller&caller_id=
    };
    $ENV{TEST_NOW} = 1651112285;
    $Created_Time = get_now()->iso8601;
    $res = $test->request(POST '/caller/', $new_caller );
    ok($res->is_success, 'returned success');

    $decoded = decode_json($res->content);
    $got = $decoded->{data};
    $expected = {
        caller_id   => 1,
        name        => $new_caller->{name},
        url         => $new_caller->{url},
        photo_url   => undef,
        created_ts  => $Created_Time,
        modified_ts => $Created_Time,
        is_deleted  => 0,
    };
    eq_or_diff $got, $expected, 'return matches';

    # now save it for the subsequent tests
    $Caller = $dbh->resultset('Caller')->find($decoded->{data}{caller_id});
    $Caller_Id = $Caller->caller_id;
};

subtest 'POST /caller duplicate' => sub {
    plan tests => 3;

    my ($expected, $res, $decoded, $got);
    my $dup_caller = {
        name        => "test caller",
    };
    local $ENV{TEST_DUP_VALUE} = 'test caller';
    warning_is {
        $res = $test->request(POST '/caller/', $dup_caller );
    } 'UNIQUE constraint failed: callers.name: test caller';

    ok($res->is_success, 'still a 200-OK though');

    $got = decode_json($res->content);
    $expected = {
        data   => "",
        errors => [ {
            msg => "There is already an entry for 'test caller' under Caller",
            num => 409,
          },
        ],
    };
    eq_or_diff $got, $expected, 'return matches';
};


subtest 'GET /caller/#' => sub{
    plan tests=>2;

    my ($res, $decoded, $got, $expected);

    $res  = $test->request( GET "/caller/$Caller_Id" );
    ok( $res->is_success, 'returned success' );

    $decoded = decode_json($res->content); 
    $got = $decoded->{data};
    $expected = {
        caller_id   => $Caller_Id,
        name        => $Caller->name,
        url         => $Caller->url,
        photo_url   => $Caller->photo_url,
        created_ts  => $Created_Time,
        modified_ts => $Created_Time,
        is_deleted  => 0,
    };
    eq_or_diff $got, $expected, 'return matches';
};


subtest 'PUT /caller/#' => sub {
    plan tests => 5;

    my ($res, $decoded, $got, $expected);
    my $edit_caller = {
        name        => "new name",
        url         => "http://new-url",
        photo_url   => $Caller->photo_url,
    };
    $ENV{TEST_NOW} += 100;
    $Modified_Time = get_now()->iso8601;
    $res = $test->request( PUT "/caller/$Caller_Id" , content => $edit_caller);
    ok( $res->is_success, 'returned success' );
    
    $decoded = decode_json($res->content);
    $got = $decoded->{data};
    $expected = {
        caller_id   => $Caller_Id,
        name        => $edit_caller->{name},
        url         => $edit_caller->{url},
        photo_url   => '',
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


    # demonstrate behavior on PUT with a non-existent pkey
    $test->put_ok('/caller/45789', { content => $edit_caller })
        or die $test->res->content;
    $decoded = decode_json($test->res->content);
    is $decoded->{errors}[0]{msg}, 'Nothing found for Caller: primary key "45789"',
        'failed PUT has expected error msg' or diag explain $decoded;
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
        url         => $Caller->url,
        photo_url   => $Caller->photo_url,
        created_ts  => $Created_Time,
        modified_ts => $Modified_Time,
        is_deleted  => 0,
      },
    ];
    eq_or_diff $got, $expected, 'matches';
};
