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

my ($Event, $Callered_Event);
my ($Event_Id, $Callered_Event_Id);
my ($Parent_Org_Id);


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
        parent_orgs => [],
        callers     => [],
        series      => [],
        styles      => [],
        venues      => [],
        bands       => [],
        talent      => [],
        created_ts  => "2022-04-28T02:18:05",
        modified_ts => "2022-04-28T02:18:05",
        is_deleted  => 0,
    };
    eq_or_diff $got, $expected, 'return matches';

    # now save it for the subsequent tests
    $Event = $dbh->resultset('Event')->find($decoded->{data}{event_id});
    $Event_Id = $Event->event_id;
};


# ******* Now adding ParentOrg *******


subtest 'POST /parent_org' => sub {
    my ($res, $decoded, $got);

    my $new_parent_org = {
        full_name    => 'Bree Country Dancing',
        abbreviation => 'BCD',
        
    };
    $res = $test->request(POST '/parent_org/', $new_parent_org );
    ok($res->is_success, 'created parent_org');
    $decoded = decode_json($res->content);
    $Parent_Org_Id = $decoded->{data}{parent_org_id};
    $got = $decoded->{data};

    my $expected = {
        parent_org_id    => $Parent_Org_Id,
        full_name        => 'Bree Country Dancing',
        abbreviation     => 'BCD',
        created_ts  => '2022-04-28T02:18:05',
        modified_ts => '2022-04-28T02:18:05',
        is_deleted  => 0,
    };

    eq_or_diff $got, $expected, 'parent_org return matches';
};

subtest 'POST /event/# with parent_org' => sub {
    plan tests => 2;

    my ($res, $decoded, $got);

    my $new_event = {
        start_time    => "2022-05-03T20:00:00",
        end_time      => "2022-05-03T22:00:00",
        is_camp       => 1,
        long_desc     => "this is the long desc",
        short_desc    => "itsa shortdesc",
        name          => "saturday night test event",
        parent_org_id => $Parent_Org_Id,
    };
    $ENV{TEST_NOW} = 1651112285;
    my $now_ts = DateTime
        ->from_epoch(epoch => $ENV{TEST_NOW})
        ->iso8601;
    $res = $test->request(POST '/event/', $new_event );
    ok($res->is_success, 'returned success');
    $decoded = decode_json($res->content);
    $got = $decoded->{data};

    $Callered_Event_Id = $got->{event_id},

    my $expected = {
        parent_orgs => [
          {
            id => 1,
            name => 'BCD',
          }
        ],
        event_id    => $Callered_Event_Id,
        start_time  => $new_event->{start_time},
        end_time    => $new_event->{end_time},
        is_camp     => $new_event->{is_camp},
        long_desc   => $new_event->{long_desc},
        short_desc  => $new_event->{short_desc},
        name        => $new_event->{name},
        is_template => undef,
        created_ts  => $now_ts,
        modified_ts => $now_ts,
        callers     => [],
        venues      => [],
        series      => [],
        styles      => [],
        bands       => [],
        talent      => [],
        is_deleted  => 0,
    };

    eq_or_diff $got, $expected, 'return matches';

    $Callered_Event = $dbh->resultset('Event')->find($Callered_Event_Id);
};

subtest "GET /event/# with parent_org" => sub {
    plan tests=>2;

    my ($expected, $res, $decoded, $got);

    $res  = $test->request( GET "/event/$Callered_Event_Id" );
    ok( $res->is_success, 'returned success' );
    $decoded = decode_json($res->content);
    $got = $decoded->{data};
    $expected = {
        created_ts  => '2022-04-28T02:18:05',
        end_time    => '2022-05-03T22:00:00',
        event_id    => $Callered_Event_Id,
        is_camp     => 1,
        is_template => undef,
        long_desc   => 'this is the long desc',
        modified_ts => '2022-04-28T02:18:05',
        name        => 'saturday night test event',
        parent_orgs => [
          {
            id => 1,
            name => 'BCD'
          }
        ],
        short_desc  => 'itsa shortdesc',
        start_time  => '2022-05-03T20:00:00',
        callers     => [],
        series      => [],
        styles      => [],
        bands       => [],
        talent      => [],
        venues      => [],
        is_deleted  => 0,
    };

    eq_or_diff $got, $expected, 'matches';
};

subtest "PUT /event/# with parent_org" => sub {
    plan tests => 4;

    my ($expected, $modified_time, $res, $decoded, $got);

    my $other_parent_org = {
        full_name        => 'Rivendell Elvish Dancers',
        abbreviation   => 'RED',
    };
    $res = $test->request(POST '/parent_org/', $other_parent_org );
    ok($res->is_success, 'created parent_org');

    $decoded = decode_json($res->content);
    my $other_parent_org_id = $decoded->{data}{parent_org_id};

    my $edit_event = {
        start_time  => "2022-05-03T21:00:00",
        end_time    => "2022-05-03T23:00:00",
        is_camp     => 0,
        long_desc   => "this is a new long desc",
        name        => "new name",
        short_desc  => "new shortdef",
        #venue_id    => [],
        style_id    => [],
        parent_org_id   => $other_parent_org_id,
    };
    $ENV{TEST_NOW} += 100;
    $modified_time = get_now();
    $res = $test->request( PUT "/event/$Callered_Event_Id" , content => $edit_event);
    ok( $res->is_success, 'returned success' );
    $decoded = decode_json($res->content);
    $got = $decoded->{data};
    $expected = {
        created_ts  => "2022-04-28T02:18:05",
        end_time    => "2022-05-03T23:00:00",
        event_id    => $Callered_Event_Id,
        is_camp     => 0,
        is_template => undef,
        long_desc   => "this is a new long desc",
        modified_ts => "2022-04-28T02:19:45",
        name        => "new name",
        parent_orgs => [
          {
            id => 2,
            name => 'RED',
          }
        ],
        short_desc  => "new shortdef",
        start_time  => "2022-05-03T21:00:00",
        callers     => [],
        venues      => [],
        series      => [],
        styles      => [],
        bands       => [],
        talent      => [],
        is_deleted  => 0,
    };
    eq_or_diff $got, $expected, 'return matches';

    $res  = $test->request( GET "/event/$Callered_Event_Id" );
    $decoded = decode_json($res->content);
    $got = $decoded->{data};

    eq_or_diff $got, $expected, 'GET changed after PUT';
};

