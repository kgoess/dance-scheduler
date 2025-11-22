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
            msg => 'Nothing found for Series: primary key "1"',
            num => 404,
        }]
    };
    is_deeply $decoded, $expected, 'error msg matches';
};

subtest 'POST /series' => sub {
    plan tests=>2;
    my ($res, $decoded, $expected, $got);

    my $new_series = {
        name       => 'Bree Trewsday English',
        series_xid => 'BREE-TREW-ENG',
        frequency  => 'second and fourth Trewsday',
        series_id   => '', # the webapp sends
                           # name=New+Series&frequency=monthly&is_deleted=0&series_id=
        display_text => 'this is display text',
        short_desc   => 'this is short desc',
        sidebar      => 'this is sidebar',
        # series_url could also be a full url like https://bree.me
        # trailing slash s/b removed and we enforce lowercase on relative urls
        series_url   => '/series/english/trewsday_ENG/',
        photo_url    => 'https://photo.jpg',
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
        series_xid            => 'BREE-TREW-ENG',
        frequency             => 'second and fourth Trewsday',
        display_text          => 'this is display text',
        short_desc            => 'this is short desc',
        sidebar               => 'this is sidebar',
        series_url            => '/series/english/trewsday_eng',
        photo_url             => 'https://photo.jpg',
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

subtest 'POST /series duplicate' => sub {
    plan tests => 3;

    my ($expected, $res, $decoded, $got);
    my $dup_series = {
        name       => 'Bree Trewsday English',
        series_xid => 'BREE-TREW-ENG',
        frequency  => 'second and fourth Trewsday',
    };
    local $ENV{TEST_DUP_VALUE} = 'BREE-TREW-ENG';
    warning_is {
        $res = $test->request(POST '/series/', $dup_series );
    } 'UNIQUE constraint failed: series.series_xid: BREE-TREW-ENG';

    ok($res->is_success, 'still a 200-OK though');

    $got = decode_json($res->content);
    $expected = {
        data   => "",
        errors => [ {
            msg => "There is already an entry for 'BREE-TREW-ENG' under Series",
            num => 409,
          },
        ],
    };
    eq_or_diff $got, $expected, 'return matches';
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
        series_xid            => 'BREE-TREW-ENG',
        frequency             => 'second and fourth Trewsday',
        display_text          => 'this is display text',
        series_url            => '/series/english/trewsday_eng',
        photo_url             => 'https://photo.jpg',
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
        series_xid        => 'BREE-TREW-ENG',
        frequency         => 'second and fourth Trewsday',
        display_text      => 'this is display text',
        short_desc        => 'this is short desc',
        sidebar           => 'this is sidebar',
        manager           => '',  # testing delete
        series_url        => 'https://changed-brie.me',
        photo_url         => 'https://changed-photo.jpg',
        programmer_notes  => 'this is programmer notes',
    };
    $res = $test->request( PUT '/series/1' , content => $edit_series);
    ok( $res->is_success, 'returned success' );
    $decoded = decode_json($res->content);

    $expected = {
        series_id             => 1,
        name                  => 'Bree Trewsday WEEKLY English',
        series_xid            => 'BREE-TREW-ENG',
        frequency             => 'second and fourth Trewsday',
        display_text          => 'this is display text',
        short_desc            => 'this is short desc',
        sidebar               => 'this is sidebar',
        manager               => '',  # testing delete
        series_url            => 'https://changed-brie.me',
        photo_url             => 'https://changed-photo.jpg',
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
    is $decoded->{errors}[0]{msg}, 'Nothing found for Series: primary key "45789"',
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
            series_xid            => 'BREE-TREW-ENG',
            frequency             => 'second and fourth Trewsday',
            display_text          => 'this is display text',
            short_desc            => 'this is short desc',
            sidebar               => 'this is sidebar',
            series_url            => 'https://changed-brie.me',
            photo_url             => 'https://changed-photo.jpg',
            manager               => '',
            programmer_notes      => 'this is programmer notes',
            created_ts            => "2022-04-28T02:18:05",
            modified_ts           => "2022-04-28T02:19:45",
            is_deleted            => 0,
        }
    ];

    eq_or_diff $got, $expected, 'matches';
};
