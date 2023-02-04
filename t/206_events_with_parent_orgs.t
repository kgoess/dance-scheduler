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

my ($Event, $Callered_Event);
my ($Event_Id, $Callered_Event_Id);
my ($Parent_Org_Id);


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


# ******* Now adding ParentOrg *******


subtest 'POST /parent_org' => sub {
    my ($res, $decoded, $got);

    my $new_parent_org = {
        full_name    => 'Bree Country Dancing',
        abbreviation => 'BCD',
        
    };
    $test->post_ok('/parent_org/', $new_parent_org );
    ok($test->success, 'created parent_org');
    $decoded = decode_json($test->content);
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
    plan tests => 3;

    my ($res, $decoded, $got);

    my $new_event = {
        start_date    => "2022-05-03",
        start_time    => "20:00",
        end_date      => "2022-05-03",
        end_time      => "22:00",
        short_desc    => "itsa shortdesc",
        name          => "saturday night test event",
        parent_org_id => $Parent_Org_Id,
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

    $Callered_Event_Id = $got->{event_id},

    my $expected = {
        parent_orgs => [
          {
            id => 1,
            name => 'BCD',
          }
        ],
    };

    eq_or_diff $got->{parent_orgs}, $expected->{parent_orgs}, 'return matches';

    $Callered_Event = $dbh->resultset('Event')->find($Callered_Event_Id);
};


subtest "GET /event/# with parent_org" => sub {
    plan tests => 3;

    my ($expected, $res, $decoded, $got);

    $test->get_ok("/event/$Callered_Event_Id" );
    ok( $test->success, 'returned success' );
    $decoded = decode_json($test->content);
    $got = $decoded->{data};
    $expected = {
        parent_orgs => [
          {
            id => 1,
            name => 'BCD'
          }
        ],
    };

    eq_or_diff $got->{parent_orgs}, $expected->{parent_orgs}, 'return matches';
};

subtest "PUT /event/# with parent_org" => sub {
    plan tests => 7;

    my ($expected, $modified_time, $res, $decoded, $got);

    my $other_parent_org = {
        full_name        => 'Rivendell Elvish Dancers',
        abbreviation   => 'RED',
    };
    $test->post_ok('/parent_org/', $other_parent_org );
    ok($test->success, 'created parent_org') or die $test->content;

    $decoded = decode_json($test->content);
    my $other_parent_org_id = $decoded->{data}{parent_org_id};

    my $edit_event = {
        start_date  => "2022-05-03",
        start_time  => "21:00",
        end_date    => "2022-05-03",
        end_time    => "23:00",
        name        => "new name",
        short_desc  => "new shortdef",
        #venue_id    => [],
        style_id    => [],
        parent_org_id   => $other_parent_org_id,
        is_canceled => 0,
    };
    $ENV{TEST_NOW} += 100;
    $modified_time = get_now();
    $test->put_ok("/event/$Callered_Event_Id", { content => $edit_event });
    ok( $test->success, 'returned success' ) or die $test->content;
    $decoded = decode_json($test->content);
    $got = $decoded->{data};
    $expected = {
        parent_orgs => [
          {
            id => 2,
            name => 'RED',
          }
        ],
    };
    eq_or_diff $got->{parent_orgs}, $expected->{parent_orgs}, 'return matches';

    $test->get_ok("/event/$Callered_Event_Id" );
    $decoded = decode_json($test->content);
    $got = $decoded->{data};

    eq_or_diff $got->{parent_orgs}, $expected->{parent_orgs}, 'GET changed after PUT';
};


