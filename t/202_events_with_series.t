use 5.16.0;
use warnings;

use Data::Dump qw/dump/;
use DateTime::Format::Strptime qw/strptime/;
use DateTime;
use JSON::MaybeXS qw/decode_json/;
use Plack::Test;
use Ref::Util qw/is_coderef/;
use Test::Differences qw/eq_or_diff/;
use Test::More tests => 7;

use bacds::Scheduler;
use bacds::Scheduler::Schema;
use bacds::Scheduler::Util::Test qw/setup_test_db get_tester/;
use bacds::Scheduler::Util::Time qw/get_now/;
use bacds::Scheduler::Util::Db qw/get_dbh/;

setup_test_db;
my $test = get_tester(auth => 1);


my $dbh = get_dbh();

my ($Event, $Seriesed_Event);
my ($Event_Id, $Seriesed_Event_Id);
my ($Series_Id);


# this could just use DBIx::Class to insert it directly
subtest 'POST /event' => sub {
    plan tests => 3;

    my ($expected, $res, $decoded, $got);

    my $new_event = {
        start_date  => "2022-05-01",
        start_time  => "20:00",
        end_date    => "2022-05-01",
        end_time    => "22:00",
        short_desc  => "itsa shortdesc",
        name        => "saturday night test event",
        is_canceled => 0,
        is_series_defaults => 0,
    };
    $ENV{TEST_NOW} = 1651112285;
    $test->post_ok('/event/', $new_event );
    ok($test->success, 'returned success');
    $decoded = decode_json($test->content);
    $got = $decoded->{data};
    $got = { map { $_ => $got->{$_} } grep { defined $got->{$_} } keys %$got };
    $expected = {
        event_id    => 1,
        start_date  => $new_event->{start_date},
        start_time  => $new_event->{start_time},
        end_date    => $new_event->{end_date},
        end_time    => $new_event->{end_time},
        short_desc  => $new_event->{short_desc},
        name        => $new_event->{name},
        callers     => [],
        parent_orgs => [],
        series      => [],
        styles      => [],
        venues      => [],
        bands       => [],
        talent      => [],
        created_ts  => "2022-04-28T02:18:05",
        modified_ts => "2022-04-28T02:18:05",
        is_deleted  => 0,
        is_canceled => 0,
        is_series_defaults => 0,
    };
    eq_or_diff $got, $expected, 'return matches';

    # now save it for the subsequent tests
    $Event = $dbh->resultset('Event')->find($decoded->{data}{event_id});
    $Event_Id = $Event->event_id;
};


# ******* Now adding Series *******


subtest 'POST /series' => sub {
    my ($res, $decoded, $got);

    my $new_series = {
        name       => 'Bree Trewsday English',
        series_xid => 'BREE-TREW-ENG',
        frequency  => 'fourth Trewsday',
    };
    $test->post_ok('/series/', $new_series );
    ok($test->success, 'created series');
    $decoded = decode_json($test->content);
    $Series_Id = $decoded->{data}{series_id};
    $got = $decoded->{data};
    $got = { map { $_ => $got->{$_} } grep { defined $got->{$_} } keys %$got };

    my $expected = {
        series_id             => $Series_Id,
        name                  => 'Bree Trewsday English',
        series_xid            => 'BREE-TREW-ENG',
        frequency             => 'fourth Trewsday',
        created_ts            => '2022-04-28T02:18:05',
        modified_ts           => '2022-04-28T02:18:05',
        is_deleted            => 0,
    };

    eq_or_diff $got, $expected, 'series return matches';
};

subtest 'POST /event/# with series' => sub {
    plan tests => 3;

    my ($res, $decoded, $got);

    my $new_event = {
        start_date  => "2022-05-03",
        start_time  => "20:00",
        end_date    => "2022-05-03",
        end_time    => "22:00",
        short_desc  => "itsa shortdesc",
        name        => "saturday night test event",
        series_id   => $Series_Id,
        is_canceled => 0,
        is_series_defaults => 0,
    };
    $ENV{TEST_NOW} = 1651112285;
    my $now_ts = DateTime
        ->from_epoch(epoch => $ENV{TEST_NOW})
        ->iso8601;
    $test->post_ok('/event/', $new_event );
    ok($test->success, 'returned success');
    $decoded = decode_json($test->content);
    $got = $decoded->{data};

    $Seriesed_Event_Id = $got->{event_id},

    my $expected = {
        series => [
          {
            id => 1,
            name => 'Bree Trewsday English',
            #series_xid => 'BREE-TREW-ENG',
          }
        ],
    };

    eq_or_diff $got->{series}, $expected->{series}, 'return matches';

    $Seriesed_Event = $dbh->resultset('Event')->find($Seriesed_Event_Id);
};

subtest "GET /event/# with series" => sub {
    plan tests => 3;

    my ($expected, $res, $decoded, $got);

    $test->get_ok("/event/$Seriesed_Event_Id" );
    ok( $test->success, 'returned success' );
    $decoded = decode_json($test->content);
    $got = $decoded->{data};
    $expected = {
        series => [
          {
            id => 1,
            name => 'Bree Trewsday English',
            #series_xid => 'BREE-TREW-ENG',
          }
        ],
    };

    eq_or_diff $got->{series}, $expected->{series}, 'matches';
};

subtest "PUT /event/# with series" => sub {
    plan tests => 7;

    my ($expected, $modified_time, $res, $decoded, $got);

    my $other_series = {
        name        => 'Fifth Mersday in Michel Delving',
        series_xid => 'MICHDELV-MONTHLY',
        frequency   => 'monthly',
    };
    $test->post_ok('/series/', $other_series );
    ok($test->success, 'created series');

    $decoded = decode_json($test->content);
    my $other_series_id = $decoded->{data}{series_id};

    my $edit_event = {
        start_date  => "2022-05-03",
        start_time  => "21:00",
        end_date    => "2022-05-03",
        end_time    => "23:00",
        name        => "new name",
        short_desc  => "new shortdef",
        #venue_id    => [],
        style_id   => [],
        series_id   => $other_series_id,
        is_canceled => 0,
    };
    $ENV{TEST_NOW} += 100;
    $modified_time = get_now();
    $test->put_ok("/event/$Seriesed_Event_Id", {content => $edit_event});
    ok( $test->success, 'returned success' ) or die $test->content;
    $decoded = decode_json($test->content);
    $got = $decoded->{data};
    $expected = {
        series => [
          {
            id => 2,
            name => 'Fifth Mersday in Michel Delving',
            #series_xid => 'MICHDELV-MONTHLY',
          }
        ],
    };
    eq_or_diff $got->{series}, $expected->{series}, 'matches';

    $test->get_ok("/event/$Seriesed_Event_Id" );
    $decoded = decode_json($test->content);
    $got = $decoded->{data};

    eq_or_diff $got->{series}, $expected->{series}, 'GET changed after PUT';
};


subtest 'GET /event/#/series_defaults_event for series when empty' => sub {
    plan tests => 3;

    my ($res, $decoded, $got);

    $test->get_ok("/series/$Series_Id/series-defaults-event");
    ok($test->success, 'returned success');
    $decoded = decode_json($test->content);
    my $expected = {
        data => {
            series => [{id=>$Series_Id}],
            is_series_defaults => 1,
        },
        errors => [],
    };

    eq_or_diff $decoded, $expected, 'return matches';

};


subtest 'POST /event/# series defaults for series' => sub {
    plan tests => 6;

    my ($res, $decoded, $got);

    my $new_event = {
        start_date  => "2022-05-03",
        start_time  => "20:00",
        end_date    => "2022-05-03",
        end_time    => "22:00",
        is_camp     => 1,
        long_desc   => "this is the long desc",
        short_desc  => "itsa shortdesc",
        name        => "saturday night test event",
        series_id   => $Series_Id,
        is_series_defaults => 1,
        is_canceled => 0,
    };
    $ENV{TEST_NOW} = 1651112285;
    my $now_ts = DateTime
        ->from_epoch(epoch => $ENV{TEST_NOW})
        ->iso8601;
    $test->post_ok('/event/', $new_event );
    ok($test->success, 'returned success');
    $decoded = decode_json($test->content);
    $got = $decoded->{data};

    $Seriesed_Event_Id = $got->{event_id},

    my $expected = {
        series => [
          {
            id => 1,
            name => 'Bree Trewsday English',
            #series_xid => 'BREE-TREW-ENG',
          }
        ],
    };

    eq_or_diff $got->{series}, $expected->{series}, 'matches';

    $Seriesed_Event = $dbh->resultset('Event')->find($Seriesed_Event_Id);

    $test->get_ok("/series/$Series_Id/series-defaults-event");
    ok($test->success, 'returned success');
    $decoded = decode_json($test->content);
    $got = $decoded->{data};

    eq_or_diff $got->{series}, $expected->{series}, 'GET after POST matches';
};


