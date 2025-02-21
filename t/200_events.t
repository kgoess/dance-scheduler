use 5.16.0;
use warnings;
use utf8;

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

my ($Event, $Second_Event);
my ($Event_Id, $Second_Event_Id);

subtest 'Invalid GET /event/1' => sub{
    plan tests=>2;

    my ($decoded, $expected);

    $test->get_ok('/event/1', '/event/1 returned success');
    $decoded = decode_json($test->content);
    $expected = {
        data => '',
        errors => [{
            msg => 'Nothing found for Event: primary key "1"',
            num => 404,
        }]
    };
    eq_or_diff $decoded, $expected, 'error msg matches';
};

subtest 'POST /event' => sub {
    plan tests=>2;

    my ($expected, $created_time, $decoded, $got);

    my $new_event = {
        event_id       => '', # this should be ignored by the model
        start_date     => "2022-05-01",
        start_time     => "20:00",
        end_date       => "2022-05-01",
        end_time       => "22:00",
        short_desc     => "itsa shortdesc",
        custom_url     => 'https://event.url',
        photo_url      => 'https://event.url/pix.png',
        custom_pricing => '¥4,000',
        name           => "saturday night test event ꙮ",
        is_canceled    => 0,
        and_friends    => 0,
        is_series_defaults    => 0,
        synthetic_name => 'Saturday Night Test',
    };
    $ENV{TEST_NOW} = 1651112285;
    $test->post_ok('/event/', $new_event, 'post to /event/ returned success' );
    $decoded = decode_json($test->res->content);
    $got = $decoded->{data};
    # With the change in this commit, the output of decode_json is utf8 octets
    # so we have to encode these logical perl characters here to match. That's
    # not right. The output of decode_json should be logical characters. We're
    # doing something wrong somwhere. But the web UI looks ok, so...?.
    $expected = {
        event_id       => 1,
        start_date     => $new_event->{start_date},
        start_time     => $new_event->{start_time},
        end_date       => $new_event->{end_date},
        end_time       => $new_event->{end_time},
        short_desc     => $new_event->{short_desc},
        long_desc      => $new_event->{long_desc},
        custom_url     => $new_event->{custom_url},
        photo_url      => $new_event->{photo_url},
        custom_pricing => '¥4,000',
        name           => $new_event->{name},
        is_canceled    => $new_event->{is_canceled},
        and_friends    => $new_event->{and_friends},
        is_series_defaults    => 0,
        callers        => [],
        parent_orgs    => [],
        role_pairs     => [],
        series         => [],
        styles         => [],
        venues         => [],
        bands          => [],
        talent         => [],
        teams          => [],
        created_ts     => "2022-04-28T02:18:05",
        modified_ts    => "2022-04-28T02:18:05",
        is_deleted     => 0,
        synthetic_name => 'Saturday Night Test',
    };
    eq_or_diff $got, $expected, 'return matches';

    # now save it for the subsequent tests
    $Event = $dbh->resultset('Event')->find($decoded->{data}{event_id});
    $Event_Id = $Event->event_id;
};


subtest "GET /event/#" => sub{
    plan tests=>2;

    my ($decoded, $got, $expected);

    $test->get_ok("/event/$Event_Id", "GET /event/$Event_Id ok");
    $decoded = decode_json($test->res->content);
    $got = $decoded->{data};

    $expected = {
        event_id       => $Event->event_id,
        start_date     => $Event->start_date->ymd('-'),
        start_time     => $Event->start_time =~ s/:00$//r,
        end_date       => $Event->end_date->ymd('-'),
        end_time       => $Event->end_time =~ s/:00$//r,
        short_desc     => $Event->short_desc,
        long_desc      => $Event->long_desc,
        custom_url     => $Event->custom_url,
        photo_url      => $Event->photo_url,
        custom_pricing => $Event->custom_pricing,
        name           => $Event->name,
        is_canceled    => $Event->is_canceled,
        and_friends    => $Event->and_friends,
        is_series_defaults    => $Event->is_series_defaults,
        created_ts     => "2022-04-28T02:18:05",
        modified_ts    => "2022-04-28T02:18:05",
        callers        => [],
        parent_orgs    => [],
        role_pairs     => [],
        series         => [],
        styles         => [],
        venues         => [],
        bands          => [],
        talent         => [],
        teams          => [],
        is_deleted     => 0,
        synthetic_name => 'Saturday Night Test',
    };

    eq_or_diff $got, $expected, 'matches';
};


subtest "PUT /event/#" => sub {
    plan tests => 6;

    my ($expected, $modified_time, $created_time, $decoded, $got);

    $created_time = get_now();

    my $edit_event = {
        start_date  => "2022-05-01",
        start_time  => "21:00",
        end_date    => "2022-05-01",
        end_time    => "23:00",
        name        => "new name",
        short_desc  => "new shortdef",
        custom_url  => "https://changed-url",
        photo_url   => 'https://event.url/pix.png',
        is_canceled => 1,
        and_friends => 0,
        synthetic_name => 'Saturday Night Test',
    };
    $ENV{TEST_NOW} += 100;
    $modified_time = get_now();
    $test->put_ok('/event/1', { content => $edit_event })
        or die $test->res->content;

    $decoded = decode_json($test->res->content);
    $got = $decoded->{data};
    $got = { map { $_ => $got->{$_} } grep { defined $got->{$_} } keys %$got };
    $expected = {
        created_ts  => "2022-04-28T02:18:05",
        modified_ts => "2022-04-28T02:19:45",
        start_date  => $edit_event->{start_date},
        start_time  => $edit_event->{start_time},
        end_date    => $edit_event->{end_date},
        end_time    => $edit_event->{end_time},
        short_desc  => $edit_event->{short_desc},
        custom_url  => $edit_event->{custom_url},
        photo_url   => $edit_event->{photo_url},
        name        => $edit_event->{name},
        is_canceled => $edit_event->{is_canceled},
        and_friends => $edit_event->{and_friends},
        event_id    => $Event_Id,
        callers     => [],
        parent_orgs => [],
        role_pairs  => [],
        series      => [],
        styles      => [],
        venues      => [],
        bands       => [],
        talent      => [],
        teams       => [],
        is_deleted  => 0,
        is_series_defaults => 0,
        custom_pricing => '¥4,000',
        synthetic_name => 'Saturday Night Test',
    };
    eq_or_diff $got, $expected, 'return matches';

    $test->get_ok("/event/$Event_Id" );
    $decoded = decode_json($test->res->content);
    $got = $decoded->{data};
    $got = { map { $_ => $got->{$_} } grep { defined $got->{$_} } keys %$got };
    eq_or_diff $got, $expected, 'GET changed after PUT';


    # update our global event object
    $Event = $dbh->resultset('Event')->find($decoded->{data}{event_id});

    # demonstrate behavior on PUT with a non-existent pkey
    $test->put_ok('/event/45789', { content => $edit_event })
        or die $test->res->content;
    $decoded = decode_json($test->res->content);
    is $decoded->{errors}[0]{msg}, 'Nothing found for Event: primary key "45789"',
        'failed PUT has expected error msg' or diag explain $decoded;
    
};


subtest 'POST /event #2' => sub{
    plan tests => 4;

    my ($expected, $decoded, $got);

    my $new_event = {
        start_date  => "2022-05-03",
        start_time  => "21:00",
        end_date    => "2022-05-03",
        end_time    => "23:00",
        short_desc  => "itsa shortdesc",
        is_canceled => 0,
        and_friends => 0,
        is_series_defaults => 0,
        name        => "saturday night test event",
    };
    $ENV{TEST_NOW} = 1651112285;
    my $now_ts = DateTime
        ->from_epoch(epoch => $ENV{TEST_NOW})
        ->iso8601;
    $test->post_ok('/event/', $new_event, 'POST /event returned ok' );

    $decoded = decode_json($test->res->content);
    $got = $decoded->{data};
    $got = { map { $_ => $got->{$_} } grep { defined $got->{$_} } keys %$got };
    $Second_Event_Id = $got->{event_id};
    $expected = {
        event_id    => $Second_Event_Id,
        start_date  => $new_event->{start_date},
        start_time  => $new_event->{start_time},
        end_date    => $new_event->{end_date},
        end_time    => $new_event->{end_time},
        is_canceled => $new_event->{is_canceled},
        and_friends => $new_event->{and_friends},
        short_desc  => $new_event->{short_desc},
        name        => $new_event->{name},
        created_ts  => $now_ts,
        modified_ts => $now_ts,
        callers     => [],
        parent_orgs => [],
        role_pairs  => [],
        series      => [],
        venues      => [],
        styles      => [],
        bands       => [],
        talent      => [],
        teams       => [],
        is_deleted  => 0,
        is_series_defaults => 0,
    };
    eq_or_diff $got, $expected, 'return from POST matches';

    $Second_Event = $dbh->resultset('Event')->find($Second_Event_Id);

    $test->get_ok('/event/'.$Second_Event_Id);
    $decoded = decode_json($test->res->content);
    $got = $decoded->{data};
    $got = { map { $_ => $got->{$_} } grep { defined $got->{$_} } keys %$got };
    eq_or_diff $got, $expected, 'return from GET matches';
};


subtest 'GET /eventAll' => sub {
    plan tests => 2;

    my ($expected, $decoded, $got);

    $test->get_ok('/eventAll', 'GET /eventAll returned ok');
    $decoded = decode_json($test->res->content);
    $got = $decoded->{data};
    $expected = [
      {
        event_id       => $Event->event_id,
        start_date     => $Event->start_date->ymd('-'),
        start_time     => $Event->start_time =~ s/:00$//r,
        end_date       => $Event->end_date->ymd('-'),
        end_time       => $Event->end_time =~ s/:00$//r,
        short_desc     => $Event->short_desc,
        long_desc      => $Event->long_desc,
        custom_url     => $Event->custom_url,
        photo_url      => $Event->photo_url,
        custom_pricing => $Event->custom_pricing,
        name           => $Event->name,
        is_canceled    => $Event->is_canceled,
        and_friends    => $Event->and_friends,
        is_series_defaults    => $Event->is_series_defaults,
        created_ts     => "2022-04-28T02:18:05",
        modified_ts    => "2022-04-28T02:19:45",
        is_deleted     => 0,
        is_series_defaults => 0,
        synthetic_name => "Saturday Night Test",
      },
      {
        event_id       => $Second_Event_Id,
        start_date     => $Second_Event->start_date->ymd('-'),
        start_time     => $Second_Event->start_time =~ s/:00$//r,
        end_date       => $Second_Event->end_date->ymd('-'),
        end_time       => $Second_Event->end_time =~ s/:00$//r,
        is_canceled    => $Second_Event->is_canceled,
        and_friends    => $Second_Event->and_friends,
        name           => $Second_Event->name,
        short_desc     => $Second_Event->short_desc,
        long_desc      => $Second_Event->long_desc,
        custom_url     => undef,
        photo_url      => undef,
        custom_pricing => undef,
        is_series_defaults    => $Second_Event->is_series_defaults,
        modified_ts    => "2022-04-28T02:18:05",
        created_ts     => "2022-04-28T02:18:05",
        is_deleted     => 0,
        is_series_defaults => 0,
        synthetic_name => undef,
      },
    ];

    eq_or_diff $got, $expected, 'matches';
};


subtest 'GET /eventsUpcoming' => sub {
    plan tests => 9;

    # could these tests all have independent data?

    my ($res, $expected, $decoded, $got);

    # on May 1 they're both in the future
    my $now = DateTime->new(
        year       => 2022,
        month      => 5,
        day        => 1,
    );
    $ENV{TEST_NOW} = $now->epoch;

    $test->get_ok('/eventsUpcoming', 'GET /eventsUpcoming ok')
        or die "GET /eventsUpcoming failed: ".$test->res->content;
    $decoded = decode_json($test->res->content);
    $got = $decoded->{data};
    is @$got, 2, "both events are in the future from $now";

    $now = $now->add(days => 1);
    $ENV{TEST_NOW} = $now->epoch;
    $test->get_ok('/eventsUpcoming', 'get /eventsUpcoming ok')
        or die "GET /eventsUpcoming failed: ".$test->res->content;
    $decoded = decode_json($test->res->content);
    $got = $decoded->{data};
    is @$got, 2, "both events are still 'upcoming' from $now";

    $now = $now->add(days => 1);
    $ENV{TEST_NOW} = $now->epoch;
    $test->get_ok('/eventsUpcoming', 'get /eventsUpcoming ok')
        or die "GET /eventsUpcoming failed: ".$test->res->content;
    $decoded = decode_json($test->res->content);
    $got = $decoded->{data};
    is @$got, 1, "only one event is future from $now";
    is $got->[0]{event_id}, $Second_Event_Id, "and it's the 'second event'";


    $now = $now->add(days => 2);
    $ENV{TEST_NOW} = $now->epoch;
    $test->get_ok('/eventsUpcoming', 'get /eventsUpcoming ok')
        or die "GET /eventsUpcoming failed: ".$test->res->content;
    $decoded = decode_json($test->res->content);
    $got = $decoded->{data};
    is @$got, 0, "no events are future from $now";
};
