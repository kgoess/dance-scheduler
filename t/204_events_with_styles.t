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

my ($Event, $Styled_Event);
my ($Event_Id, $Styled_Event_Id);
my ($Style_Id);


# this could just use DBIx::Class to insert it directly
subtest 'POST /event' => sub {
    plan tests => 3;

    my ($expected, $decoded, $got);

    my $new_event = {
        start_date  => "2022-05-01",
        start_time  => "20:00",
        end_date    => "2022-05-01",
        end_time    => "22:00",
        long_desc   => "this is the long desc",
        short_desc  => "itsa shortdesc",
        name        => "saturday night test event",
        style_id    => undef,
        is_canceled => 0,
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
        talent      => [],
        series      => [],
        styles      => [],
        venues      => [],
        bands       => [],
        callers     => [],
        parent_orgs => [],
        created_ts  => "2022-04-28T02:18:05",
        modified_ts => "2022-04-28T02:18:05",
        is_canceled => 0,
        is_deleted  => 0,
    };
    eq_or_diff $got, $expected, 'return matches';

    # now save it for the subsequent tests
    $Event = $dbh->resultset('Event')->find($decoded->{data}{event_id});
    $Event_Id = $Event->event_id;
};


# ******* Now adding Style *******


subtest 'POST /style' => sub {
    my ($decoded, $got);

    my $new_style = {
        name       => 'Rose Gamgee',
        frequency  => 'fourth Trewsday',
        
    };
    $test->post_ok('/style/', $new_style );
    ok($test->success, 'created style');
    $decoded = decode_json($test->content);
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
    plan tests => 3;

    my ($decoded, $got);

    my $new_event = {
        start_date  => "2022-05-03",
        start_time  => "20:00",
        end_date    => "2022-05-03",
        end_time    => "22:00",
        short_desc  => "itsa shortdesc",
        name        => "saturday night test event",
        style_id    => $Style_Id,
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

    $Styled_Event_Id = $got->{event_id},

    my $expected = {
        styles => [
          {
            id => 1,
            name => 'Rose Gamgee'
          }
        ],
    };

    eq_or_diff $got->{styles}, $expected->{styles}, 'return matches';

    $Styled_Event = $dbh->resultset('Event')->find($Styled_Event_Id);
};

subtest "GET /event/# with style" => sub {
    plan tests => 3;

    my ($expected, $decoded, $got);

    $test->get_ok("/event/$Styled_Event_Id" );
    ok( $test->success, 'returned success' );
    $decoded = decode_json($test->content);
    $got = $decoded->{data};
    $expected = {
        styles => [
          {
            id => 1,
            name => 'Rose Gamgee'
          }
        ],
    };

    eq_or_diff $got->{styles}, $expected->{styles}, 'return matches';
};

subtest "PUT /event/# with style" => sub {
    plan tests => 7;

    my ($expected, $modified_time, $decoded, $got);

    my $other_style = {
        name        => 'Daffodil Brandybuck',
    };
    $test->post_ok('/style/', $other_style );
    ok($test->success, 'created style') or die $test->content;

    $decoded = decode_json($test->content);
    my $other_style_id = $decoded->{data}{style_id};

    my $edit_event = {
        start_date  => "2022-05-03",
        start_time  => "21:00",
        end_date    => "2022-05-03",
        end_time    => "23:00",
        name        => "new name",
        short_desc  => "new shortdef",
        style_id    => $other_style_id,
    };
    $ENV{TEST_NOW} += 100;
    $modified_time = get_now();
    $test->put_ok("/event/$Styled_Event_Id" , {content => $edit_event});
    ok( $test->success, 'returned success' ) or die $test->content;
    $decoded = decode_json($test->content);
    $got = $decoded->{data};
    $expected = {
        styles => [
          {
            id => 2,
            name => 'Daffodil Brandybuck',
          }
        ],
    };
    eq_or_diff $got->{styles}, $expected->{styles}, 'return matches';

    $test->get_ok("/event/$Styled_Event_Id" );
    $decoded = decode_json($test->content);
    $got = $decoded->{data};

    eq_or_diff $got->{styles}, $expected->{styles}, 'GET changed after PUT';
};


