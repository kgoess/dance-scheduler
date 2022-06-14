use 5.16.0;
use warnings;

use Data::Dump qw/dump/;
use DateTime::Format::Strptime qw/strptime/;
use DateTime;
use HTTP::Request::Common;
use JSON qw/decode_json/;
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

my ($Event, $Styled_Event);
my ($Event_Id, $Styled_Event_Id);
my ($Style_Id);


# this could just use DBIx::Class to insert it directly
subtest 'POST /event' => sub {
    plan tests=>2;

    my ($expected, $res, $decoded, $got);

    my $new_event = {
        start_time  => "2022-05-01T20:00:00",
        end_time    => "2022-05-01T22:00:00",
        is_camp     => 1,
        long_desc   => "this is the long desc",
        short_desc  => "itsa shortdesc",
        name        => "saturday night test event",
        style_id   => undef,
    };
    $ENV{TEST_NOW} = 1651112285;
    $res = $test->request(POST '/event/', $new_event );
    ok($res->is_success, 'returned success');
    $decoded = decode_json($res->content);
    $got = $decoded->{data};
    $expected = {
        event_id    => 1,
        start_time  => $new_event->{start_time},
        end_time    => $new_event->{end_time},
        is_camp     => $new_event->{is_camp},
        long_desc   => $new_event->{long_desc},
        short_desc  => $new_event->{short_desc},
        name        => $new_event->{name},
        is_template => undef,
        talent      => [],
        series      => [],
        styles      => [],
        venues      => [],
        bands       => [],
        callers     => [],
        parent_orgs => [],
        created_ts  => "2022-04-28T02:18:05",
        modified_ts => "2022-04-28T02:18:05",
        is_deleted  => 0,
    };
    eq_or_diff $got, $expected, 'return matches';

    # now save it for the subsequent tests
    $Event = $dbh->resultset('Event')->find($decoded->{data}{event_id});
    $Event_Id = $Event->event_id;
};


# ******* Now adding Style *******


subtest 'POST /style' => sub {
    my ($res, $decoded, $got);

    my $new_style = {
        name       => 'Rose Gamgee',
        frequency  => 'fourth Trewsday',
        
    };
    $res = $test->request(POST '/style/', $new_style );
    ok($res->is_success, 'created style');
    $decoded = decode_json($res->content);
    $Style_Id = $decoded->{data}{style_id};
    $got = $decoded->{data};

    my $expected = {
        style_id    => $Style_Id,
        name        => 'Rose Gamgee',
        created_ts  => '2022-04-28T02:18:05',
        modified_ts => '2022-04-28T02:18:05',
        is_deleted  => 0,
    };

    eq_or_diff $got, $expected, 'style return matches';
};

subtest 'POST /event/# with style' => sub {
    plan tests => 2;

    my ($res, $decoded, $got);

    my $new_event = {
        start_time  => "2022-05-03T20:00:00",
        end_time    => "2022-05-03T22:00:00",
        is_camp     => 1,
        long_desc   => "this is the long desc",
        short_desc  => "itsa shortdesc",
        name        => "saturday night test event",
        style_id   => $Style_Id,
    };
    $ENV{TEST_NOW} = 1651112285;
    my $now_ts = DateTime
        ->from_epoch(epoch => $ENV{TEST_NOW})
        ->iso8601;
    $res = $test->request(POST '/event/', $new_event );
    ok($res->is_success, 'returned success');
    $decoded = decode_json($res->content);
    $got = $decoded->{data};

    $Styled_Event_Id = $got->{event_id},

    my $expected = {
        styles => [
          {
            id => 1,
            name => 'Rose Gamgee'
          }
        ],
        event_id    => $Styled_Event_Id,
        start_time  => $new_event->{start_time},
        end_time    => $new_event->{end_time},
        is_camp     => $new_event->{is_camp},
        long_desc   => $new_event->{long_desc},
        short_desc  => $new_event->{short_desc},
        name        => $new_event->{name},
        is_template => undef,
        created_ts  => $now_ts,
        modified_ts => $now_ts,
        venues      => [],
        series      => [],
        talent      => [],
        bands       => [],
        callers     => [],
        parent_orgs => [],
        is_deleted  => 0,
    };

    eq_or_diff $got, $expected, 'return matches';

    $Styled_Event = $dbh->resultset('Event')->find($Styled_Event_Id);
};

subtest "GET /event/# with style" => sub {
    plan tests=>2;

    my ($expected, $res, $decoded, $got);

    $res  = $test->request( GET "/event/$Styled_Event_Id" );
    ok( $res->is_success, 'returned success' );
    $decoded = decode_json($res->content);
    $got = $decoded->{data};
    $expected = {
        created_ts  => '2022-04-28T02:18:05',
        end_time    => '2022-05-03T22:00:00',
        event_id    => $Styled_Event_Id,
        is_camp     => 1,
        is_template => undef,
        long_desc   => 'this is the long desc',
        modified_ts => '2022-04-28T02:18:05',
        name        => 'saturday night test event',
        styles => [
          {
            id => 1,
            name => 'Rose Gamgee'
          }
        ],
        short_desc  => 'itsa shortdesc',
        start_time  => '2022-05-03T20:00:00',
        series      => [],
        talent      => [],
        venues      => [],
        bands       => [],
        callers     => [],
        parent_orgs => [],
        is_deleted  => 0,
    };

    eq_or_diff $got, $expected, 'matches';
};

subtest "PUT /event/# with style" => sub {
    plan tests => 4;

    my ($expected, $modified_time, $res, $decoded, $got);

    my $other_style = {
        name        => 'Daffodil Brandybuck',
    };
    $res = $test->request(POST '/style/', $other_style );
    ok($res->is_success, 'created style');

    $decoded = decode_json($res->content);
    my $other_style_id = $decoded->{data}{style_id};

    my $edit_event = {
        start_time  => "2022-05-03T21:00:00",
        end_time    => "2022-05-03T23:00:00",
        is_camp     => 0,
        long_desc   => "this is a new long desc",
        name        => "new name",
        short_desc  => "new shortdef",
        style_id    => $other_style_id,
    };
    $ENV{TEST_NOW} += 100;
    $modified_time = get_now();
    $res = $test->request( PUT "/event/$Styled_Event_Id" , content => $edit_event);
    ok( $res->is_success, 'returned success' );
    $decoded = decode_json($res->content);
    $got = $decoded->{data};
    $expected = {
        created_ts  => "2022-04-28T02:18:05",
        end_time    => "2022-05-03T23:00:00",
        event_id    => $Styled_Event_Id,
        is_camp     => 0,
        is_template => undef,
        long_desc   => "this is a new long desc",
        modified_ts => "2022-04-28T02:19:45",
        name        => "new name",
        styles => [
          {
            id => 2,
            name => 'Daffodil Brandybuck',
          }
        ],
        short_desc  => "new shortdef",
        start_time  => "2022-05-03T21:00:00",
        venues      => [],
        series      => [],
        talent      => [],
        bands       => [],
        callers     => [],
        parent_orgs => [],
        is_deleted  => 0,
    };
    eq_or_diff $got, $expected, 'return matches';

    $res  = $test->request( GET "/event/$Styled_Event_Id" );
    $decoded = decode_json($res->content);
    $got = $decoded->{data};

    eq_or_diff $got, $expected, 'GET changed after PUT';
};


