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
use bacds::Scheduler::Util::Db qw/get_dbh/;
use bacds::Scheduler::Util::Test qw/setup_test_db get_tester/;
use bacds::Scheduler::Util::Time qw/get_now/;

setup_test_db;
my $test = get_tester(auth => 1);
my $dbh = get_dbh();

my ($Event, $Callered_Event);
my ($Event_Id, $Callered_Event_Id);
my ($Caller_Id);


# this could just use DBIx::Class to insert it directly
subtest 'POST /event' => sub {
    plan tests => 3;

    my ($expected, $decoded, $got);

    my $new_event = {
        start_date  => "2022-05-01",
        start_time  => "20:00",
        end_date    => "2022-05-01",
        end_time    => "22:00",
        short_desc  => "itsa shortdesc",
        name        => "saturday night test event",
        caller_id   => undef,
        is_canceled => 0,
        and_friends => 0,
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
        and_friends => 0,
        is_series_defaults => 0,
    };
    eq_or_diff $got, $expected, 'return matches';

    # now save it for the subsequent tests
    $Event = $dbh->resultset('Event')->find($decoded->{data}{event_id});
    $Event_Id = $Event->event_id;
};


# ******* Now adding Caller *******


subtest 'POST /caller' => sub {
    my ($decoded, $got);

    my $new_caller = {
        name       => 'Rose Gamgee',
        frequency  => 'fourth Trewsday',
        
    };
    $test->post_ok('/caller/', $new_caller );
    ok($test->success, 'created caller');
    $decoded = decode_json($test->content);
    $Caller_Id = $decoded->{data}{caller_id};
    $got = $decoded->{data};

    my $expected = {
        caller_id   => $Caller_Id,
        name        => 'Rose Gamgee',
        url         => undef,
        photo_url   => undef,
        created_ts  => '2022-04-28T02:18:05',
        modified_ts => '2022-04-28T02:18:05',
        is_deleted  => 0,
    };

    eq_or_diff $got, $expected, 'caller return matches';
};

subtest 'POST /event/# with caller' => sub {
    plan tests => 3;

    my ($decoded, $got);

    my $new_event = {
        start_date  => "2022-05-03",
        start_time  => "20:00",
        end_date    => "2022-05-03",
        end_time    => "22:00",
        short_desc  => "itsa shortdesc",
        name        => "saturday night test event",
        caller_id   => $Caller_Id,
        is_canceled => 0,
        and_friends => 0,
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
        callers => [
          {
            id => 1,
            name => 'Rose Gamgee'
          }
        ],
    };

    eq_or_diff $got->{callers}, $expected->{callers}, 'return matches';

    $Callered_Event = $dbh->resultset('Event')->find($Callered_Event_Id);
};

subtest "GET /event/# with caller" => sub {
    plan tests => 3;

    my ($expected, $decoded, $got);

    $test->get_ok("/event/$Callered_Event_Id" );
    ok( $test->success, 'returned success' );
    $decoded = decode_json($test->content);
    $got = $decoded->{data};
    $expected = {
        callers => [
          {
            id => 1,
            name => 'Rose Gamgee'
          }
        ],
    };

    eq_or_diff $got->{callers}, $expected->{callers}, 'return matches';
};

subtest "PUT /event/# with caller" => sub {
    plan tests => 7;

    my ($expected, $modified_time, $decoded, $got);

    my $other_caller = {
        name        => 'Daffodil Brandybuck',
        frequency   => 'monthly',
    };
    $test->post_ok('/caller/', $other_caller );
    ok($test->success, 'created caller');

    $decoded = decode_json($test->content);
    my $other_caller_id = $decoded->{data}{caller_id};

    my $edit_event = {
        start_date  => "2022-05-03",
        start_time  => "21:00",
        end_date    => "2022-05-03",
        end_time    => "23:00",
        name        => "new name",
        short_desc  => "new shortdef",
        #venue_id    => [],
        style_id   => [],
        caller_id   => $other_caller_id,
        is_canceled => 0,
    };
    $ENV{TEST_NOW} += 100;
    $modified_time = get_now();
    $test->put_ok("/event/$Callered_Event_Id" , { content => $edit_event });
    ok( $test->success, 'returned success' );
    $decoded = decode_json($test->content);
    $got = $decoded->{data};
    $expected = {
        callers => [
          {
            id => 2,
            name => 'Daffodil Brandybuck',
          }
        ],
    };
    eq_or_diff $got->{callers}, $expected->{callers}, 'return matches';

    $test->get_ok("/event/$Callered_Event_Id" );
    $decoded = decode_json($test->content);
    $got = $decoded->{data};

    eq_or_diff $got->{callers}, $expected->{callers}, 'GET changed after PUT';
};


