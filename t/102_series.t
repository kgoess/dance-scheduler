use 5.16.0;
use warnings;

use Data::Dump qw/dump/;
use DateTime;
use DateTime::Format::Strptime qw/strptime/;
use JSON qw/decode_json/;
use HTTP::Request::Common;
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

my ($Series, $Series_Id);

subtest 'Invalid GET /series/1' => sub{
    plan tests=>2;
    my ($res, $decoded, $expected);

    $res = $test->request( GET '/series/1' );
    ok($res->is_success, 'returned success');
    $decoded = decode_json($res->content);
    $expected = {
        errors => [{
            msg => 'Nothing Found for series_id 1',
            num => 1800,
        }]
    };
    is_deeply $decoded, $expected, 'error msg matches';
};

subtest 'POST /series' => sub{
    plan tests=>2;
    my ($res, $decoded, $expected, $got);

    my $new_series = {
        name       => 'Bree Trewsday English',
        frequency  => 'second and fourth Trewday',
    };
    $ENV{TEST_NOW} = 1651112285;
    $res = $test->request(POST '/series/', $new_series);
    ok($res->is_success, 'returned success');
    $decoded = decode_json($res->content);
    $got = $decoded->{data};
    $expected = {
        series_id    => 1,
        name        => 'Bree Trewsday English',
        frequency  => 'second and fourth Trewday',
        created_ts  => "2022-04-28T02:18:05",
        modified_ts => "2022-04-28T02:18:05",
        is_deleted  => 0,
    };
    eq_or_diff $got, $expected, 'return matches';

    # now save it for the subsequent tests
    $Series = $dbh->resultset('Series')->find($decoded->{data}{series_id});
    $Series_Id = $Series->series_id;
};


subtest 'GET /series/#' => sub {
    plan tests=>2;
    my ($res, $decoded, $got, $expected);

    $res = $test->request( GET "/series/$Series_Id" );
    ok( $res->is_success, 'returned success' );
    $decoded = decode_json($res->content); 
    $got = $decoded->{data};
    $expected = {
        series_id    => 1,
        name        => 'Bree Trewsday English',
        frequency  => 'second and fourth Trewday',
        created_ts  => "2022-04-28T02:18:05",
        modified_ts => "2022-04-28T02:18:05",
        is_deleted  => 0,
    };

    eq_or_diff $got, $expected, 'matches';
};


subtest 'PUT /series/1' => sub {
    plan tests => 3;
    my ($expected, $res, $decoded, $got);

    $ENV{TEST_NOW} += 100;

    my $edit_series = {
        name       => 'Bree Trewsday WEEKLY English',
        frequency  => 'second and fourth Trewsday',
    };
    $res = $test->request( PUT '/series/1' , content => $edit_series);
    ok( $res->is_success, 'returned success' );
    $decoded = decode_json($res->content);

    $expected = {
        series_id   => 1,
        name        => 'Bree Trewsday WEEKLY English',
        frequency   => 'second and fourth Trewsday',
        created_ts  => "2022-04-28T02:18:05",
        modified_ts => "2022-04-28T02:19:45",
        is_deleted  => 0,
    };

    $got = $decoded->{data};
    eq_or_diff $got, $expected, 'matches';

    $res  = $test->request( GET '/series/1' );
    $decoded = decode_json($res->content); 
    $got = $decoded->{data};
    eq_or_diff $got, $expected, 'GET changed after PUT';

    # update our global series object
    $Series = $dbh->resultset('Series')->find($decoded->{data}{series_id});

};

subtest 'GET /seriesAll' => sub {
    plan tests => 2;
    my ($res, $expected, $decoded, $got);

    $res  = $test->request( GET '/seriesAll' );
    ok( $res->is_success, 'Returned success' );
    $decoded = decode_json($res->content);
    $got = $decoded->{data};
    $expected = [
        {
            series_id    => 1,
            name        => 'Bree Trewsday WEEKLY English',
            frequency  => 'second and fourth Trewsday',
            created_ts  => "2022-04-28T02:18:05",
            modified_ts => "2022-04-28T02:19:45",
            is_deleted  => 0,
        }
    ];

    eq_or_diff $got, $expected, 'matches';
};
