use 5.16.0;
use warnings;

use Data::Dump qw/dump/;
use DateTime::Format::Strptime qw/strptime/;
use DateTime;
use JSON::MaybeXS qw/decode_json/;
use Plack::Test;
use Ref::Util qw/is_coderef/;
use Test::Differences qw/eq_or_diff/;
use Test::More tests => 5;

use bacds::Scheduler;
use bacds::Scheduler::Schema;
use bacds::Scheduler::Util::Test qw/setup_test_db get_tester/;
use bacds::Scheduler::Util::Time qw/get_now/;
use bacds::Scheduler::Util::Db qw/get_dbh/;

setup_test_db;
my $test = get_tester(auth => 1);
my $dbh = get_dbh();

my ($Event, $Teamed_Event);
my ($Event_Id, $Teamed_Event_Id);
my ($Team_Id);


# this could just use DBIx::Class to insert it directly
subtest 'POST /event' => sub {
    plan tests => 3;

    my ($expected, $res, $decoded, $got);

    my $new_event = {
        start_date => "2022-05-01",
        start_time => "20:00",

        end_date => "2022-05-01",
        end_time => "22:00",

        short_desc  => "itsa shortdesc",
        is_canceled => 0,
        and_friends => 0,
        is_series_defaults => 0,
        name        => "saturday night test event",
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
        parent_orgs => [],
        callers     => [],
        series      => [],
        styles      => [],
        venues      => [],
        bands       => [],
        talent      => [],
        teams       => [],
        created_ts  => "2022-04-28T02:18:05",
        modified_ts => "2022-04-28T02:18:05",
        is_deleted  => 0,
        is_canceled  => 0,
        and_friends  => 0,
        is_series_defaults => 0,
    };
    eq_or_diff $got, $expected, 'return matches';

    # now save it for the subsequent tests
    $Event = $dbh->resultset('Event')->find($decoded->{data}{event_id});
    $Event_Id = $Event->event_id;
};


# ******* Now adding Team *******


subtest 'POST /team' => sub {
    my ($res, $decoded, $got);

    my $new_team = {
        name => 'Bree Morris',
        team_xid => 'BREEMORRIS',
    };
    $test->post_ok('/team/', $new_team );
    ok($test->success, 'created team');
    $decoded = decode_json($test->content);
    $Team_Id = $decoded->{data}{team_id};
    $got = $decoded->{data};

    my $expected = {
        contact => undef,
        description => undef,
        photo_url => undef,
        sidebar => undef,
        styles => [],
        team_url => undef,
        team_id => $Team_Id,
        name => 'Bree Morris',
        team_xid => 'BREEMORRIS',
        created_ts => '2022-04-28T02:18:05',
        modified_ts => '2022-04-28T02:18:05',
        is_deleted  => 0,
    };

    eq_or_diff $got, $expected, 'team return matches';
};

subtest 'POST /event/# with team' => sub {
    plan tests => 3;

    my ($res, $decoded, $got);

    my $new_event = {
        start_date    => "2022-05-03",
        start_time    => "20:00",
        end_date      => "2022-05-03",
        end_time      => "22:00",
        short_desc    => "itsa shortdesc",
        name          => "saturday night test event",
        team_id => $Team_Id,
        is_deleted    => 0,
        is_canceled   => 0,
        and_friends   => 0,
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

    $Teamed_Event_Id = $got->{event_id},

    my $expected = {
        teams => [
          {
            id => 1,
            name => 'Bree Morris',
          }
        ],
    };

    eq_or_diff $got->{teams}, $expected->{teams}, 'return matches';

    $Teamed_Event = $dbh->resultset('Event')->find($Teamed_Event_Id);
};


subtest "GET /event/# with team" => sub {
    plan tests => 3;

    my ($expected, $res, $decoded, $got);

    $test->get_ok("/event/$Teamed_Event_Id" );
    ok( $test->success, 'returned success' );
    $decoded = decode_json($test->content);
    $got = $decoded->{data};
    $expected = {
        teams => [
          {
            id => 1,
            name => 'Bree Morris'
          }
        ],
    };

    eq_or_diff $got->{teams}, $expected->{teams}, 'return matches';
};

subtest "PUT /event/# with team" => sub {
    plan tests => 7;

    my ($expected, $modified_time, $res, $decoded, $got);

    my $other_team = {
        name => 'Rivendell Elvish Dance Celebration',
        team_xid => 'RED',
    };
    $test->post_ok('/team/', $other_team );
    ok($test->success, 'created team') or die $test->content;

    $decoded = decode_json($test->content);
    my $other_team_id = $decoded->{data}{team_id};

    my $edit_event = {
        start_date  => "2022-05-03",
        start_time  => "21:00",
        end_date    => "2022-05-03",
        end_time    => "23:00",
        name        => "new name",
        short_desc  => "new shortdef",
        #venue_id    => [],
        style_id    => [],
        team_id   => $other_team_id,
        is_canceled => 0,
    };
    $ENV{TEST_NOW} += 100;
    $modified_time = get_now();
    $test->put_ok("/event/$Teamed_Event_Id", { content => $edit_event });
    ok( $test->success, 'returned success' ) or die $test->content;
    $decoded = decode_json($test->content);
    $got = $decoded->{data};
    $expected = {
        teams => [
          {
            id => 2,
            name => 'Rivendell Elvish Dance Celebration',
          }
        ],
    };
    eq_or_diff $got->{teams}, $expected->{teams}, 'return matches';

    $test->get_ok("/event/$Teamed_Event_Id" );
    $decoded = decode_json($test->content);
    $got = $decoded->{data};

    eq_or_diff $got->{teams}, $expected->{teams}, 'GET changed after PUT';
};


