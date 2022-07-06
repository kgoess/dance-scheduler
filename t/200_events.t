use 5.16.0;
use warnings;

use Data::Dump qw/dump/;
use DateTime::Format::Strptime qw/strptime/;
use DateTime;
use HTTP::Request::Common;
use JSON::MaybeXS qw/decode_json/;
use Plack::Test;
use Ref::Util qw/is_coderef/;
use Test::Differences qw/eq_or_diff/;
use Test::More tests => 7;

use bacds::Scheduler;
use bacds::Scheduler::Schema;
use bacds::Scheduler::Util::Time qw/get_now/;
use bacds::Scheduler::Util::Db qw/get_dbh/;

use bacds::Scheduler::Util::TestDb qw/setup_test_db/;
setup_test_db;

my $app = bacds::Scheduler->to_app;
my $test = Plack::Test->create($app);
my $dbh = get_dbh();

my ($Event, $Second_Event);
my ($Event_Id, $Second_Event_Id);

subtest 'Invalid GET /event/1' => sub{
    plan tests=>2;

    my ($res, $decoded, $expected);

    $res = $test->request( GET '/event/1' );
    ok($res->is_success, 'returned success');
    $decoded = decode_json($res->content);
    $expected = {
        data => '',
        errors => [{
            msg => 'Nothing Found for event_id 1',
            num => 1100,
        }]
    };
    eq_or_diff $decoded, $expected, 'error msg matches';
};

subtest 'POST /event' => sub {
    plan tests=>2;

    my ($expected, $created_time, $res, $decoded, $got);

    my $new_event = {
        event_id    => '', # this should be ignored by the model
        start_date  => "2022-05-01",
        start_time  => "20:00",
        end_date    => "2022-05-01",
        end_time    => "22:00",
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
        start_date  => $new_event->{start_date},
        start_time  => $new_event->{start_time},
        end_date    => $new_event->{end_date},
        end_time    => $new_event->{end_time},
        is_camp     => $new_event->{is_camp},
        long_desc   => $new_event->{long_desc},
        short_desc  => $new_event->{short_desc},
        name        => $new_event->{name},
        is_template => undef,
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
    };
    eq_or_diff $got, $expected, 'return matches';

    # now save it for the subsequent tests
    $Event = $dbh->resultset('Event')->find($decoded->{data}{event_id});
    $Event_Id = $Event->event_id;
};


subtest "GET /event/#" => sub{
    plan tests=>2;

    my ($res, $decoded, $got, $expected);

    $res  = $test->request( GET "/event/$Event_Id" );
    ok( $res->is_success, 'returned success' );
    $decoded = decode_json($res->content); 
    $got = $decoded->{data};

    $expected = {
        event_id    => $Event->event_id,
        start_date  => $Event->start_date->ymd('-'),
        start_time  => $Event->start_time =~ s/:00$//r,
        end_date    => $Event->end_date->ymd('-'),
        end_time    => $Event->end_time =~ s/:00$//r,
        is_camp     => $Event->is_camp,
        long_desc   => $Event->long_desc,
        short_desc  => $Event->short_desc,
        name        => $Event->name,
        is_template => $Event->is_template,
        created_ts  => "2022-04-28T02:18:05",
        modified_ts => "2022-04-28T02:18:05",
        callers     => [],
        parent_orgs => [],
        series      => [],
        styles      => [],
        venues      => [],
        bands       => [],
        talent      => [],
        is_deleted  => 0,
    };

    eq_or_diff $got, $expected, 'matches';
};


subtest "PUT /event/#" => sub {
    plan tests => 3;

    my ($expected, $modified_time, $created_time, $res, $decoded, $got);

    $created_time = get_now();

    my $edit_event = {
        start_date  => "2022-05-01",
        start_time  => "21:00",
        end_date    => "2022-05-01",
        end_time    => "23:00",
        is_camp     => 0,
        long_desc   => "this is a new long desc",
        name        => "new name",
        short_desc  => "new shortdef",
    };
    $ENV{TEST_NOW} += 100;
    $modified_time = get_now();
    $res = $test->request( PUT '/event/1' , content => $edit_event);
    ok( $res->is_success, 'returned success' );

    $decoded = decode_json($res->content);
    $got = $decoded->{data};
    $expected = {
        created_ts  => "2022-04-28T02:18:05",
        modified_ts => "2022-04-28T02:19:45",
        start_date  => "2022-05-01",
        start_time  => "21:00",
        end_date    => "2022-05-01",
        end_time    => "23:00",
        event_id    => $Event_Id,
        is_camp     => 0,
        is_template => undef,
        long_desc   => "this is a new long desc",
        name        => "new name",
        short_desc  => "new shortdef",
        callers     => [],
        parent_orgs => [],
        series      => [],
        styles      => [],
        venues      => [],
        bands       => [],
        talent      => [],
        is_deleted  => 0,
    };
    eq_or_diff $got, $expected, 'return matches';

    $res  = $test->request( GET "/event/$Event_Id" );
    $decoded = decode_json($res->content); 
    $got = $decoded->{data};
    eq_or_diff $got, $expected, 'GET changed after PUT';


    # update our global event object
    $Event = $dbh->resultset('Event')->find($decoded->{data}{event_id});
};


subtest 'POST /event #2' => sub{
    plan tests=>3;

    my ($expected, $res, $decoded, $got);

    my $new_event = {
        start_date  => "2022-05-03",
        start_time  => "21:00",
        end_date    => "2022-05-03",
        end_time    => "23:00",
        is_camp     => 1,
        long_desc   => "this is the long desc",
        short_desc  => "itsa shortdesc",
        name        => "saturday night test event",
    };
    $ENV{TEST_NOW} = 1651112285;
    my $now_ts = DateTime
        ->from_epoch(epoch => $ENV{TEST_NOW})
        ->iso8601;
    $res = $test->request(POST '/event/', $new_event );
    ok($res->is_success, 'returned success');

    $decoded = decode_json($res->content);
    $got = $decoded->{data};
    $Second_Event_Id = $got->{event_id};
    $expected = {
        event_id    => $Second_Event_Id,
        start_date  => $new_event->{start_date},
        start_time  => $new_event->{start_time},
        end_date    => $new_event->{end_date},
        end_time    => $new_event->{end_time},
        is_camp     => $new_event->{is_camp},
        long_desc   => $new_event->{long_desc},
        short_desc  => $new_event->{short_desc},
        name        => $new_event->{name},
        is_template => undef,
        created_ts  => $now_ts,
        modified_ts => $now_ts,
        callers     => [],
        parent_orgs => [],
        series      => [],
        venues      => [],
        styles      => [],
        bands       => [],
        talent      => [],
        is_deleted  => 0,
    };
    eq_or_diff $got, $expected, 'return from POST matches';

    $Second_Event = $dbh->resultset('Event')->find($Second_Event_Id);

    $res = $test->request(GET '/event/'.$Second_Event_Id);
    $decoded = decode_json($res->content);
    $got = $decoded->{data};
    eq_or_diff $got, $expected, 'return from GET matches';
};


subtest 'GET /eventAll' => sub {
    plan tests => 2;

    my ($res, $expected, $decoded, $got);

    $res  = $test->request( GET '/eventAll' );
    ok( $res->is_success, 'Returned success' );
    $decoded = decode_json($res->content);
    $got = $decoded->{data};
    $expected = [
      {
        start_date  => "2022-05-01",
        start_time  => "21:00",
        end_date    => "2022-05-01",
        end_time    => "23:00",
        event_id    => $Event_Id,
        is_camp     => 0,
        is_template => undef,
        long_desc   => "this is a new long desc",
        modified_ts => "2022-04-28T02:19:45",
        name        => "new name",
        short_desc  => "new shortdef",
        created_ts  => "2022-04-28T02:18:05",
        is_deleted  => 0,
      },
      {
        event_id    => $Second_Event_Id,
        start_date  => $Second_Event->start_date->ymd('-'),
        start_time  => $Second_Event->start_time =~ s/:00$//r,
        end_date    => $Second_Event->end_date->ymd('-'),
        end_time    => $Second_Event->end_time =~ s/:00$//r,
        is_camp     => $Second_Event->is_camp,
        long_desc   => $Second_Event->long_desc,
        short_desc  => $Second_Event->short_desc,
        name        => $Second_Event->name,
        is_template => $Second_Event->is_template,
        modified_ts => "2022-04-28T02:18:05",
        created_ts  => "2022-04-28T02:18:05",
        is_deleted  => 0,
      },
    ];

    eq_or_diff $got, $expected, 'matches';
};


subtest 'GET /eventsUpcoming' => sub {
    plan tests => 5;

    # could these tests all have independent data?

    my ($res, $expected, $decoded, $got);

    # on May 1 they're both in the future
    my $now = DateTime->new(
        year       => 2022,
        month      => 5,
        day        => 1,
    );
    $ENV{TEST_NOW} = $now->epoch;

    $res  = $test->request( GET '/eventsUpcoming' );
    $res->is_success or die "GET /eventsUpcoming failed: ".$res->content;
    $decoded = decode_json($res->content);
    $got = $decoded->{data};
    is @$got, 2, "both events are in the future from $now";

    $now = $now->add(days => 1);
    $ENV{TEST_NOW} = $now->epoch;
    $res  = $test->request( GET '/eventsUpcoming' );
    $res->is_success or die "GET /eventsUpcoming failed: ".$res->content;
    $decoded = decode_json($res->content);
    $got = $decoded->{data};
    is @$got, 2, "both events are still 'upcoming' from $now";

    $now = $now->add(days => 1);
    $ENV{TEST_NOW} = $now->epoch;
    $res  = $test->request( GET '/eventsUpcoming' );
    $res->is_success or die "GET /eventsUpcoming failed: ".$res->content;
    $decoded = decode_json($res->content);
    $got = $decoded->{data};
    is @$got, 1, "only one event is future from $now";
    is $got->[0]{event_id}, $Second_Event_Id, "and it's the 'second event'";


    $now = $now->add(days => 2);
    $ENV{TEST_NOW} = $now->epoch;
    $res  = $test->request( GET '/eventsUpcoming' );
    $res->is_success or die "GET /eventsUpcoming failed: ".$res->content;
    $decoded = decode_json($res->content);
    $got = $decoded->{data};
    is @$got, 0, "no events are future from $now";

};
