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

use bacds::Scheduler;
use bacds::Scheduler::Schema;
use bacds::Scheduler::Util::Time qw/get_now/;
use bacds::Scheduler::Util::Db qw/get_dbh/;

use bacds::Scheduler::Util::Test qw/setup_test_db get_tester/;
setup_test_db;

my $app = bacds::Scheduler->to_app;
my $test = get_tester(auth => 1);
my $dbh = get_dbh();

my $Style;
my $Style_Id;
my $Created_Time;
my $Modified_Time;


subtest 'Invalid GET /style/1' => sub{
    plan tests=>2;

    my ($res, $decoded, $got, $expected);
    $res = $test->request( GET '/style/1' );
    ok($res->is_success, 'returned success');

    $decoded = decode_json($res->content);
    $expected = {
        data => '',
        errors => [{
            msg => 'Nothing found for style_id 1',
            num => 1401,
        }]
    };
    eq_or_diff $decoded, $expected, 'error msg matches';
};

subtest 'POST /style' => sub{
    plan tests=>2;

    my ($expected, $res, $decoded, $got);
    my $new_style = {
        name        => "test style",
        style_id   => '', # the webapp sends name=test+style&style_id=
    };
    $ENV{TEST_NOW} = 1651112285;
    $Created_Time = get_now()->iso8601;
    $res = $test->request(POST '/style/', $new_style );
    ok($res->is_success, 'returned success');

    $decoded = decode_json($res->content);
    $got = $decoded->{data};
    $expected = {
        style_id    => 1,
        name        => $new_style->{name},
        created_ts  => $Created_Time,
        modified_ts => $Created_Time,
        is_deleted  => 0,
    };
    eq_or_diff $got, $expected, 'return matches';

    # now save it for the subsequent tests
    $Style = $dbh->resultset('Style')->find($decoded->{data}{style_id});
    $Style_Id = $Style->style_id;
};


subtest 'GET /style/#' => sub{
    plan tests=>2;

    my ($res, $decoded, $got, $expected);

    $res  = $test->request( GET "/style/$Style_Id" );
    ok( $res->is_success, 'returned success' );

    $decoded = decode_json($res->content); 
    $got = $decoded->{data};
    $expected = {
        style_id    => $Style_Id,
        name        => $Style->name,
        created_ts  => $Created_Time,
        modified_ts => $Created_Time,
        is_deleted  => 0,
    };
    eq_or_diff $got, $expected, 'return matches';
};


subtest 'PUT /style/#' => sub {
    plan tests => 5;

    my ($res, $decoded, $got, $expected);
    my $edit_style = {
        name        => "new name",
    };
    $ENV{TEST_NOW} += 100;
    $Modified_Time = get_now()->iso8601;
    $res = $test->request( PUT "/style/$Style_Id" , content => $edit_style);
    ok( $res->is_success, 'returned success' );
    
    $decoded = decode_json($res->content);
    $got = $decoded->{data};
    $expected = {
        style_id    => $Style_Id,
        name        => $edit_style->{name},
        created_ts  => $Created_Time,
        modified_ts => $Modified_Time,
        is_deleted  => 0,
    };
    eq_or_diff $got, $expected, 'return matches';

    $res  = $test->request( GET "/style/$Style_Id" );
    $decoded = decode_json($res->content); 
    $got = $decoded->{data};
    eq_or_diff $got, $expected, 'GET changed after PUT';

    # update our global style object
    $Style = $dbh->resultset('Style')->find($Style_Id);

    # demonstrate behavior on PUT with a non-existent pkey
    $test->put_ok('/style/45789', { content => $edit_style })
        or die $test->res->content;
    $decoded = decode_json($test->res->content);
    is $decoded->{errors}[0]{msg}, "Update failed for PUT /style: style_id '45789' not found",
        'failed PUT has expected error msg' or diag explain $decoded;
};


subtest 'GET /styleAll' => sub{
    plan tests => 2;

    my ($res, $decoded, $got, $expected);
    $res  = $test->request( GET '/styleAll' );
    ok( $res->is_success, 'Returned success' );

    $decoded = decode_json($res->content);
    $got = $decoded->{data};
    $expected = [
      {
        style_id    => $Style_Id,
        name        => $Style->name,
        created_ts  => $Created_Time,
        modified_ts => $Modified_Time,
        is_deleted  => 0,
      },
    ];
    eq_or_diff $got, $expected, 'matches';
    
};

subtest 'GET /styleAll with deleted' => sub{
    plan tests => 3;
    my ($res, $decoded, $got, $expected);
    my $edit_style = {
        is_deleted        => 1,
    };
    $res = $test->request( PUT "/style/$Style_Id" , content => $edit_style);
    ok( $res->is_success, 'PUT returned success' );

    $res  = $test->request( GET '/styleAll' );
    ok( $res->is_success, 'GET Returned success' );
    $decoded = decode_json($res->content);
    $got = $decoded->{data};
    $expected = [
    ];
    eq_or_diff $got, $expected, 'deleted style did not show';
};
