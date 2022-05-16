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
use Test::More tests => 8;
use URL::Encode qw/url_encode/;

use bacds::Scheduler;
use bacds::Scheduler::Schema;
use bacds::Scheduler::Util::Time qw/get_now/;

unlink "testdb";

$ENV{TEST_DSN} = 'dbi:SQLite:dbname=testdb';
# load an on-disk test database and deploy the required tables
bacds::Scheduler::Schema->connection($ENV{TEST_DSN},'','');
bacds::Scheduler::Schema->load_namespaces;
bacds::Scheduler::Schema->deploy;

my $app = bacds::Scheduler->to_app;
my $test = Plack::Test->create($app);

subtest 'Invalid GET /event/1' => sub{
    plan tests=>2;

    my ($res, $decoded, $expected);

    $res = $test->request( GET '/event/1' );
    ok($res->is_success, 'returned success');
    $decoded = decode_json($res->content);
    $expected = {
        errors => [{
            msg => 'Nothing Found for event_id 1',
            num => 1100,
        }]
    };
    is_deeply $decoded, $expected, 'error msg matches';
};

subtest 'POST /event' => sub{
    plan tests=>2;

    my ($expected, $created_time, $res, $decoded, $got);

    $expected = {
        start_time  => "2022-05-01T20:00:00",
        end_time    => "2022-05-01T22:00:00",
        is_camp     => 1,
        long_desc   => "this is the long desc",
        name        => "saturday night test event",
        series_id   => undef,
        short_desc  => "itsa shortdesc",
    };
    $ENV{TEST_NOW} = 1651112285;
    $created_time = get_now();
    $res = $test->request(POST '/event/', $expected );
    ok($res->is_success, 'returned success');
    $decoded = decode_json($res->content);
    $got = {};
    $expected->{created_ts} = $expected->{modified_ts} = $created_time;
    foreach my $key (keys %$expected){
        $got->{$key} = $decoded->{data}{$key};
    };
    is_deeply $got, $expected, 'return matches';
};


subtest 'GET /event/1' => sub{
    plan tests=>2;

    my ($res, $decoded, $got, $expected);

    $res  = $test->request( GET '/event/1' );
    ok( $res->is_success, 'returned success' );
    $decoded = decode_json($res->content); 
    $got = {};
    foreach my $key (keys %$expected){
        $got->{$key} = $decoded->{data}{$key};
    };
    is_deeply $got, $expected, 'matches';
};


subtest 'PUT /event/1' => sub {
    plan tests => 3;

    my ($expected, $modified_time, $created_time, $res, $decoded, $got);

    $created_time = get_now();

    $expected = {
        start_time  => "2022-05-01T21:00:00",
        end_time    => "2022-05-01T23:00:00",
        is_camp     => 0,
        long_desc   => "this is a new long desc",
        name        => "new name",
        short_desc  => "new shortdef",
    };
    $ENV{TEST_NOW} += 100;
    $modified_time = get_now();
    $res = $test->request( PUT '/event/1' , content => $expected);
    $expected->{created_ts} = $created_time;
    ok( $res->is_success, 'returned success' );
    $decoded = decode_json($res->content);
    $got = {};
    foreach my $key (keys %$expected){
        $got->{$key} = $decoded->{data}{$key};
    };
    is_deeply $got, $expected, 'return matches';

    $res  = $test->request( GET '/event/1' );
    $decoded = decode_json($res->content); 
    $expected->{created_ts} = $created_time;
    $expected->{modified_ts} = $modified_time;
    foreach my $key (keys %$expected){
        $got->{$key} = $decoded->{data}{$key};
    };
    is_deeply $got, $expected, 'GET changed after PUT';
};

# *******Now adding styles *******

my $Style_Id;
subtest 'POST /event with styles' => sub{
    plan tests=>4;

    my ($expected, $res, $decoded, $got, $created_time);

    $expected = {
        name        => "test style",
    };
    $res = $test->request(POST '/style/', $expected );
    ok($res->is_success, 'created style');
    $decoded = decode_json($res->content);
    $Style_Id = $decoded->{data}{style_id};
    $got = {};
    foreach my $key (keys %$expected){
        $got->{$key} = $decoded->{data}{$key};
    };

    is_deeply $got, $expected, 'style return matches';


    my $new_event = {
        start_time  => "2022-05-01T20:00:00",
        end_time    => "2022-05-01T22:00:00",
        is_camp     => 1,
        long_desc   => "this is the long desc",
        short_desc  => "itsa shortdesc",
        name        => "saturday night test event",
        series_id   => undef,
        style_id   => [$Style_Id],
    };
    $ENV{TEST_NOW} = 1651112285;
    my $now_ts = DateTime
        ->from_epoch(epoch => $ENV{TEST_NOW})
        ->iso8601;
    $res = $test->request(POST '/event/', $new_event );
    ok($res->is_success, 'returned success');
    $decoded = decode_json($res->content);
    $created_time = get_now()->iso8601;
    $new_event->{created_ts}      =
        $new_event->{modified_ts} =
        $created_time;
    $got = $decoded->{data};
    $expected = {
        start_time  => $new_event->{start_time},
        end_time    => $new_event->{end_time},
        is_camp     => $new_event->{is_camp},
        long_desc   => $new_event->{long_desc},
        short_desc  => $new_event->{short_desc},
        name        => $new_event->{name},
        series_id   => undef,
        is_template => undef,
        created_ts  => $now_ts,
        modified_ts => $now_ts,
        event_id    => 2,
        styles      => [{ id => $Style_Id, name => "test style" }],
    };

    eq_or_diff $got, $expected, 'return matches';
};


subtest 'GET /event/1' => sub{
    plan tests=>2;

    my ($expected, $res, $decoded, $got);

    $res  = $test->request( GET '/event/1' );
    ok( $res->is_success, 'returned success' );
    $decoded = decode_json($res->content); 
    $got = $decoded->{data};
    $expected = {
        created_ts  => "2022-04-28T02:18:05",
        end_time    => "2022-05-01T23:00:00",
        event_id    => 1,
        is_camp     => 0,
        is_template => undef,
        long_desc   => "this is a new long desc",
        modified_ts => "2022-04-28T02:19:45",
        name        => "new name",
        series_id   => undef,
        short_desc  => "new shortdef",
        start_time  => "2022-05-01T21:00:00",
    };

    is_deeply $got, $expected, 'matches';
};


subtest 'PUT /event/1' => sub {
    plan tests => 3;

    my ($expected, $created_time, $modified_time, $res, $decoded, $got);

    my $edit_event = {
        start_time  => "2022-05-01T21:00:00",
        end_time    => "2022-05-01T23:00:00",
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
        end_time    => "2022-05-01T23:00:00",
        event_id    => 1,
        is_camp     => 0,
        is_template => undef,
        long_desc   => "this is a new long desc",
        modified_ts => "2022-04-28T02:19:45",
        name        => "new name",
        series_id   => undef,
        short_desc  => "new shortdef",
        start_time  => "2022-05-01T21:00:00",
    };
    is_deeply $got, $expected, 'return matches';

    $res  = $test->request( GET '/event/1' );
    $decoded = decode_json($res->content); 
    $got = $decoded->{data};

    is_deeply $got, $expected, 'GET changed after PUT';
};

subtest 'GET /eventAll' => sub{
    plan tests => 2;

    my ($res, $expected, $decoded, $got);

    $res  = $test->request( GET '/eventAll' );
    ok( $res->is_success, 'Returned success' );
    $expected->{event_id} = 1;
    $decoded = decode_json($res->content);
    $got = $decoded->{data};
    $expected = [
      {
        created_ts  => "2022-04-28T02:18:05",
        end_time    => "2022-05-01T23:00:00",
        event_id    => 1,
        is_camp     => 0,
        is_template => undef,
        long_desc   => "this is a new long desc",
        modified_ts => "2022-04-28T02:19:45",
        name        => "new name",
        series_id   => undef,
        short_desc  => "new shortdef",
        start_time  => "2022-05-01T21:00:00",
      },
      {
        created_ts  => "2022-04-28T02:18:05",
        end_time    => "2022-05-01T22:00:00",
        event_id    => 2,
        is_camp     => 1,
        is_template => undef,
        long_desc   => "this is the long desc",
        modified_ts => "2022-04-28T02:18:05",
        name        => "saturday night test event",
        series_id   => undef,
        short_desc  => "itsa shortdesc",
        start_time  => "2022-05-01T20:00:00",
      },
    ];

    is_deeply $got, $expected, 'matches';
};
