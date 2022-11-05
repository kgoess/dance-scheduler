use 5.16.0;
use warnings;

use Data::Dump qw/dump/;
use DateTime;
use DateTime::Format::Strptime qw/strptime/;
use JSON::MaybeXS qw/decode_json/;
use HTTP::Request::Common;
use Plack::Test;
use Ref::Util qw/is_coderef/;

use Test::Differences qw/eq_or_diff/;
use Test::More tests => 5;

use bacds::Scheduler;
use bacds::Scheduler::Schema;
use bacds::Scheduler::Util::Time qw/get_now/;
use bacds::Scheduler::Util::Db qw/get_dbh/;

use bacds::Scheduler::Util::Test qw/setup_test_db get_tester/;
setup_test_db;

my $app = bacds::Scheduler->to_app;
my $test = get_tester(auth => 1);
my $dbh = get_dbh();

my ($Series, $Series_Id);

subtest 'Invalid GET /series/1' => sub{
    plan tests=>2;
    my ($res, $decoded, $expected);

    $res = $test->request( GET '/series/1' );
    ok($res->is_success, 'returned success');
    $decoded = decode_json($res->content);
    $expected = {
        data => '',
        errors => [{
            msg => 'Nothing Found for series_id 1',
            num => 2000,
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
        series_id   => '', # the webapp sends
                           # name=New+Series&frequency=monthly&is_deleted=0&series_id=
        display_text => 'this is display text',
        short_desc   => 'this is short desc',
        sidebar      => 'this is sidebar',
        series_url   => 'https://bree.me',
        manager      => 'Mary Manager',
        programmer_notes => 'this is programmer notes',
    };
    $ENV{TEST_NOW} = 1651112285;
    $res = $test->request(POST '/series/', $new_series);
    ok($res->is_success, 'returned success');
    $decoded = decode_json($res->content);
    $got = $decoded->{data};
    $expected = {
        series_id             => 1,
        name                  => 'Bree Trewsday English',
        frequency             => 'second and fourth Trewday',
        display_text          => 'this is display text',
        short_desc            => 'this is short desc',
        sidebar               => 'this is sidebar',
        series_url            => 'https://bree.me',
        manager               => 'Mary Manager',
        programmer_notes      => 'this is programmer notes',
        created_ts            => "2022-04-28T02:18:05",
        modified_ts           => "2022-04-28T02:18:05",
        is_deleted            => 0,
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
        series_id             => 1,
        name                  => 'Bree Trewsday English',
        frequency             => 'second and fourth Trewday',
        display_text          => 'this is display text',
        series_url            => 'https://bree.me',
        short_desc            => 'this is short desc',
        sidebar               => 'this is sidebar',
        manager               => 'Mary Manager',
        programmer_notes      => 'this is programmer notes',
        created_ts            => "2022-04-28T02:18:05",
        modified_ts           => "2022-04-28T02:18:05",
        is_deleted            => 0,
    };

    eq_or_diff $got, $expected, 'matches';
};


subtest 'PUT /series/1' => sub {
    plan tests => 5;
    my ($expected, $res, $decoded, $got);

    $ENV{TEST_NOW} += 100;

    my $edit_series = {
        name              => 'Bree Trewsday WEEKLY English',
        frequency         => 'second and fourth Trewsday',
        display_text      => 'this is display text',
        short_desc        => 'this is short desc',
        sidebar           => 'this is sidebar',
        series_url        => 'https://changed-brie.me',
        programmer_notes  => 'this is programmer notes',
    };
    $res = $test->request( PUT '/series/1' , content => $edit_series);
    ok( $res->is_success, 'returned success' );
    $decoded = decode_json($res->content);

    $expected = {
        series_id             => 1,
        name                  => 'Bree Trewsday WEEKLY English',
        frequency             => 'second and fourth Trewsday',
        display_text          => 'this is display text',
        short_desc            => 'this is short desc',
        sidebar               => 'this is sidebar',
        series_url            => 'https://changed-brie.me',
        programmer_notes      => 'this is programmer notes',
        created_ts            => "2022-04-28T02:18:05",
        modified_ts           => "2022-04-28T02:19:45",
        is_deleted            => 0,
    };

    $got = $decoded->{data};
    $got = { map { $_ => $got->{$_} } grep { defined $got->{$_} } keys %$got };

    eq_or_diff $got, $expected, 'matches';

    $res  = $test->request( GET '/series/1' );
    $decoded = decode_json($res->content); 
    $got = $decoded->{data};
    $got = { map { $_ => $got->{$_} } grep { defined $got->{$_} } keys %$got };
    eq_or_diff $got, $expected, 'GET changed after PUT';

    # update our global series object
    $Series = $dbh->resultset('Series')->find($decoded->{data}{series_id});


    # demonstrate behavior on PUT with a non-existent pkey
    $test->put_ok('/series/45789', { content => $edit_series })
        or die $test->res->content;
    $decoded = decode_json($test->res->content);
    is $decoded->{errors}[0]{msg}, "Update failed for PUT /series: series_id '45789' not found",
        'failed PUT has expected error msg' or diag explain $decoded;
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
            series_id             => 1,
            name                  => 'Bree Trewsday WEEKLY English',
            frequency             => 'second and fourth Trewsday',
            display_text          => 'this is display text',
            short_desc            => 'this is short desc',
            sidebar               => 'this is sidebar',
            series_url            => 'https://changed-brie.me',
            manager               => undef,
            programmer_notes      => 'this is programmer notes',
            created_ts            => "2022-04-28T02:18:05",
            modified_ts           => "2022-04-28T02:19:45",
            is_deleted            => 0,
        }
    ];

    eq_or_diff $got, $expected, 'matches';
};
