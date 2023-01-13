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
use Test::More tests => 12;
use Test::Warn;

use bacds::Scheduler;
use bacds::Scheduler::Schema;
use bacds::Scheduler::Util::Time qw/get_now/;
use bacds::Scheduler::Util::Db qw/get_dbh/;

use bacds::Scheduler::Util::Test qw/get_tester setup_test_db get_tester/;
setup_test_db;

my $app = bacds::Scheduler->to_app;
my $test = get_tester(auth => 1);
my $dbh = get_dbh();

my $Programmer;
my $Programmer_Id;
my $Programmer_With_Event;
my $Programmer_With_Event_Id;
my $Programmer_With_Series;
my $Programmer_With_Series_Id;
my $Created_Time;
my $Modified_Time;
my $Modified_Time_With_Series;
my $Modified_Time_With_Event;


my $Event1 = $dbh->resultset('Event')->new({
    name => 'test event 1',
    synthetic_name => 'test event 1 synthname',
    start_date => get_now->ymd('-'),
    start_time => '20:00',
});
$Event1->insert;
my $Event2 = $dbh->resultset('Event')->new({
    name => 'test event 2',
    synthetic_name => 'test event 2 synthname',
    start_date => get_now->ymd('-'),
    start_time => '20:00',
});
$Event2->insert;
my $Event3 = $dbh->resultset('Event')->new({
    name => 'test event 3',
    synthetic_name => 'test event 3 synthname',
    start_date => get_now->ymd('-'),
    start_time => '20:00',
});
$Event3->insert;


my $Series1 = $dbh->resultset('Series')->new({
    name => 'test series 1',
    series_xid => 'TS1',
});
$Series1->insert;
my $Series2 = $dbh->resultset('Series')->new({
    name => 'test series 1',
    series_xid => 'TS2',
});
$Series2->insert;
my $Series3 = $dbh->resultset('Series')->new({
    name => 'test series 3',
    series_xid => 'TS3',
});
$Series3->insert;


# note that setup_test_db adds a programmer to seed the table
subtest 'Invalid GET /programmer/2' => sub {
    plan tests=>2;

    my ($res, $decoded, $got, $expected);
    $res = $test->request( GET '/programmer/2' );
    ok($res->is_success, 'returned success');

    $decoded = decode_json($res->content);
    $expected = {
        data => '',
        errors => [{
            msg => 'Nothing found for Programmer: primary key "2"',
            num => 404,
        }]
    };
    eq_or_diff $decoded, $expected, 'error msg matches';
};

subtest 'POST /programmer' => sub {
    plan tests => 2;

    my $atest = get_tester(auth => 1);

    my ($expected, $res, $decoded, $got);
    my $new_programmer = {
        name          => 'alice programmer',
        email         => 'alice@test.com',
        is_superuser  => 1,
        programmer_id => '', # the webapp sends name=test+programmer&programmer_id=
    };
    $ENV{TEST_NOW} = 1651112285;
    $Created_Time = get_now()->iso8601;
    $res = $atest->request(POST '/programmer/', $new_programmer );
    ok($res->is_success, 'returned success');

    $decoded = decode_json($res->content);
    $got = $decoded->{data};
    $expected = {
        programmer_id    => 2,
        name         => $new_programmer->{name},
        email        => $new_programmer->{email},
        is_superuser => $new_programmer->{is_superuser},
        created_ts   => $Created_Time,
        modified_ts  => $Created_Time,
        events       => [],
        series       => [],
        events       => [],
        is_deleted   => 0,
    };
    eq_or_diff $got, $expected, 'return matches';

    # now save it for the subsequent tests
    $Programmer = $dbh->resultset('Programmer')->find($decoded->{data}{programmer_id});
    $Programmer_Id = $Programmer->programmer_id;
};

subtest 'POST /programmer duplicate' => sub {
    plan tests => 3;

    my ($expected, $res, $decoded, $got);
    my $dup_programmer = {
        name          => 'alice programmer',
        email         => 'alice@test.com',
        is_superuser  => 0,
    };
    local $ENV{TEST_DUP_VALUE} = 'alice@test.com';
    warning_is {
        $res = $test->request(POST '/programmer/', $dup_programmer );
    } 'UNIQUE constraint failed: programmers.email: alice@test.com';

    ok($res->is_success, 'still a 200-OK though');

    $got = decode_json($res->content);
    $expected = {
        data   => "",
        errors => [ {
            msg => q{There is already an entry for 'alice@test.com' under Programmer},
            num => 409,
          },
        ],
    };
    eq_or_diff $got, $expected, 'return matches';
};

subtest 'POST /programmer with series' => sub {
    plan tests => 2;

    my $atest = get_tester(auth => 1);

    my ($expected, $res, $decoded, $got);
    my $new_programmer = {
        name          => 'bob programmer',
        email         => 'bob@test.com',
        password_hash => 'thisisthepasswordhash',
        is_superuser  => 1,
        programmer_id => '', # the webapp sends name=test+programmer&programmer_id=
        series_id => [ $Series1->series_id, $Series2->series_id ],
    };
    $ENV{TEST_NOW} = 1651112285;
    $Created_Time = get_now()->iso8601;
    $res = $test->request(POST '/programmer/', $new_programmer );
    ok($res->is_success, 'returned success');

    $decoded = decode_json($res->content);
    $got = $decoded->{data};
    $expected = {
        programmer_id => 3,
        name          => $new_programmer->{name},
        email         => $new_programmer->{email},
        is_superuser  => $new_programmer->{is_superuser},
        created_ts    => $Created_Time,
        modified_ts   => $Created_Time,
        events        => [],
        series => [
            {
                id   => $Series1->series_id,
                name => $Series1->name,
            },
            {
                id   => $Series2->series_id,
                name => $Series2->name,
            },
        ],
        events       => [],
        is_deleted   => 0,
    };
    eq_or_diff $got, $expected, 'return matches';

    # now save it for the subsequent tests
    $Programmer_With_Series = $dbh->resultset('Programmer')->find($decoded->{data}{programmer_id});
    $Programmer_With_Series_Id = $Programmer_With_Series->programmer_id;
};

subtest 'POST /programmer with events' => sub{
    plan tests=>2;

    my ($expected, $res, $decoded, $got);
    my $new_programmer = {
        name          => 'chuck contradancer',
        email         => 'chuck@test.com',
        password_hash => 'thisisthepasswordhash',
        is_superuser  => 1,
        programmer_id => '', # the webapp sends name=test+programmer&programmer_id=
        event_id => [ $Event1->event_id, $Event2->event_id ],
    };
    $ENV{TEST_NOW} = 1651112285;
    $Created_Time = get_now()->iso8601;
    $res = $test->request(POST '/programmer/', $new_programmer );
    ok($res->is_success, 'returned success');

    $decoded = decode_json($res->content);
    $got = $decoded->{data};
    $expected = {
        programmer_id => 4,
        name          => $new_programmer->{name},
        email         => $new_programmer->{email},
        is_superuser  => $new_programmer->{is_superuser},
        created_ts    => $Created_Time,
        modified_ts   => $Created_Time,
        series        => [],
        events => [
            {
                id   => $Event1->event_id,
                name => $Event1->synthetic_name,
            },
            {
                id   => $Event2->event_id,
                name => $Event2->synthetic_name,
            },
        ],
        is_deleted   => 0,
    };
    eq_or_diff $got, $expected, 'return matches';

    # now save it for the subsequent tests
    $Programmer_With_Event = $dbh->resultset('Programmer')->find($decoded->{data}{programmer_id});
    $Programmer_With_Event_Id = $Programmer_With_Event->programmer_id;
};

subtest 'GET /programmer/2' => sub {
    plan tests=>2;

    my ($res, $decoded, $got, $expected);

    $res  = $test->request( GET "/programmer/$Programmer_Id" );
    ok( $res->is_success, 'returned success' );

    $decoded = decode_json($res->content);
    $got = $decoded->{data};
    $expected = {
        programmer_id  => $Programmer_Id,
        name           => $Programmer->name,
        email          => $Programmer->email,
        is_superuser   => $Programmer->is_superuser,
        created_ts     => $Created_Time,
        modified_ts    => $Created_Time,
        is_deleted     => 0,
        events         => [],
        series         => [],
        events         => [],
    };
    eq_or_diff $got, $expected, 'return matches';
};

subtest 'GET /programmer/2 (with series)' => sub {
    plan tests=>2;

    my ($res, $decoded, $got, $expected);

    $res  = $test->request( GET "/programmer/$Programmer_With_Series_Id" );
    ok( $res->is_success, 'returned success' );

    $decoded = decode_json($res->content);
    $got = $decoded->{data};
    $expected = {
        programmer_id  => $Programmer_With_Series_Id,
        name           => $Programmer_With_Series->name,
        email          => $Programmer_With_Series->email,
        is_superuser   => $Programmer_With_Series->is_superuser,
        created_ts     => $Created_Time,
        modified_ts    => $Created_Time,
        is_deleted     => 0,
        events         => [],
        series => [
            {
                id   => $Series1->series_id,
                name => $Series1->name,
            },
            {
                id   => $Series2->series_id,
                name => $Series2->name,
            },
        ],
        events => [],
    };
    eq_or_diff $got, $expected, 'return matches';
};
subtest 'GET /programmer/3 (with events)' => sub{
    plan tests=>2;

    my ($res, $decoded, $got, $expected);

    $res  = $test->request( GET "/programmer/$Programmer_With_Event_Id" );
    ok( $res->is_success, 'returned success' );

    $decoded = decode_json($res->content);
    $got = $decoded->{data};
    $expected = {
        programmer_id  => $Programmer_With_Event_Id,
        name           => $Programmer_With_Event->name,
        email          => $Programmer_With_Event->email,
        is_superuser   => $Programmer_With_Event->is_superuser,
        created_ts     => $Created_Time,
        modified_ts    => $Created_Time,
        is_deleted     => 0,
        series         => [],
        events => [
            {
                id   => $Event1->event_id,
                name => $Event1->synthetic_name,
            },
            {
                id   => $Event2->event_id,
                name => $Event2->synthetic_name,
            },
        ],
    };
    eq_or_diff $got, $expected, 'return matches';
};


subtest 'PUT /programmer/#' => sub {
    plan tests => 5;

    my ($res, $decoded, $got, $expected);
    my $edit_programmer = {
        name        => 'new name',
        email       => 'newemail@newemail.com',
    };
    $ENV{TEST_NOW} += 100;
    $Modified_Time = get_now()->iso8601;
    $res = $test->request( PUT "/programmer/$Programmer_Id" , content => $edit_programmer);
    ok( $res->is_success, 'returned success' );

    $decoded = decode_json($res->content);
    $got = $decoded->{data};
    $expected = {
        programmer_id => $Programmer_Id,
        name          => $edit_programmer->{name},
        email         => $edit_programmer->{email},
        is_superuser  => 1,
        events        => [],
        series        => [],
        created_ts  => $Created_Time,
        modified_ts => $Modified_Time,
        is_deleted  => 0,
    };
    eq_or_diff $got, $expected, 'return matches';

    $res  = $test->request( GET "/programmer/$Programmer_Id" );
    $decoded = decode_json($res->content);
    $got = $decoded->{data};
    eq_or_diff $got, $expected, 'GET changed after PUT';

    # update our global programmer object
    $Programmer = $dbh->resultset('Programmer')->find($Programmer_Id);


    # demonstrate behavior on PUT with a non-existent pkey
    $test->put_ok('/programmer/45789', { content => $edit_programmer })
        or die $test->res->content;
    $decoded = decode_json($test->res->content);
    is $decoded->{errors}[0]{msg}, 'Nothing found for Programmer: primary key "45789"',
        'failed PUT has expected error msg' or diag explain $decoded;
};

subtest 'PUT /programmer/# 2 (with series)' => sub {
    plan tests => 3;

    my ($res, $decoded, $got, $expected);
    my $edit_programmer = {
        name           => $Programmer_With_Series->name,
        email          => $Programmer_With_Series->email,
        is_superuser   => $Programmer_With_Series->is_superuser,
        series_id      => [ $Series3->series_id],
    };
    $ENV{TEST_NOW} += 100;
    $Modified_Time_With_Series = get_now()->iso8601;
    $res = $test->request( PUT "/programmer/$Programmer_With_Series_Id" , content => $edit_programmer);
    ok( $res->is_success, 'returned success' );

    $decoded = decode_json($res->content);
    $got = $decoded->{data};
    $expected = {
        programmer_id  => $Programmer_With_Series_Id,
        name           => $Programmer_With_Series->name,
        email          => $Programmer_With_Series->email,
        is_superuser   => $Programmer_With_Series->is_superuser,
        events         => [],
        series => [
            {
                id => $Series3->series_id,
                name => $Series3->name,
            },
        ],
        events      => [],
        created_ts  => $Created_Time,
        modified_ts => $Modified_Time_With_Series,
        is_deleted  => 0,
    };
    eq_or_diff $got, $expected, 'return matches';

    $res  = $test->request( GET "/programmer/$Programmer_With_Series_Id" );
    $decoded = decode_json($res->content);
    $got = $decoded->{data};
    eq_or_diff $got, $expected, 'GET changed after PUT';

    # update our global programmer object
    $Programmer = $dbh->resultset('Programmer')->find($Programmer_Id);
};


subtest 'PUT /programmer/# 3 (with events)' => sub {
    plan tests => 3;

    my ($res, $decoded, $got, $expected);
    my $edit_programmer = {
        name           => $Programmer_With_Event->name,
        email          => $Programmer_With_Event->email,
        is_superuser   => $Programmer_With_Event->is_superuser,
        event_id      => [ $Event3->event_id],
    };
    $ENV{TEST_NOW} += 100;
    $Modified_Time_With_Event = get_now()->iso8601;
    $res = $test->request( PUT "/programmer/$Programmer_With_Event_Id" , content => $edit_programmer);
    ok( $res->is_success, 'returned success' );

    $decoded = decode_json($res->content);
    $got = $decoded->{data};
    $expected = {
        programmer_id  => $Programmer_With_Event_Id,
        name           => $Programmer_With_Event->name,
        email          => $Programmer_With_Event->email,
        is_superuser   => $Programmer_With_Event->is_superuser,
        series         => [],
        events => [
            {
                id => $Event3->event_id,
                name => $Event3->synthetic_name,
            },
        ],
        created_ts  => $Created_Time,
        modified_ts => $Modified_Time_With_Event,
        is_deleted  => 0,
    };
    eq_or_diff $got, $expected, 'return matches';

    $res  = $test->request( GET "/programmer/$Programmer_With_Event_Id" );
    $decoded = decode_json($res->content);
    $got = $decoded->{data};
    eq_or_diff $got, $expected, 'GET changed after PUT';

    # update our global programmer object
    $Programmer = $dbh->resultset('Programmer')->find($Programmer_Id);
};

subtest 'GET /programmerAll' => sub {
    plan tests => 2;

    my ($res, $decoded, $got, $expected);
    $res  = $test->request( GET '/programmerAll' );
    ok( $res->is_success, 'Returned success' );

    $decoded = decode_json($res->content);
    $got = $decoded->{data};
    $got = [ grep { $_->{email} ne 'petertheadmin@test.com' } @$got ];
    $expected = [
      {
        programmer_id => $Programmer_With_Series_Id,
        name          => $Programmer_With_Series->name,
        email         => $Programmer_With_Series->email,
        is_superuser  => $Programmer_With_Series->is_superuser,
        created_ts    => $Created_Time,
        modified_ts   => $Modified_Time_With_Series,
        is_deleted    => 0,
      },
      {
        programmer_id => $Programmer_With_Event_Id,
        name          => $Programmer_With_Event->name,
        email         => $Programmer_With_Event->email,
        is_superuser  => $Programmer_With_Event->is_superuser,
        created_ts    => $Created_Time,
        modified_ts   => $Modified_Time_With_Event,
        is_deleted    => 0,
      },
      {
        programmer_id => $Programmer_Id,
        name          => $Programmer->name,
        email         => $Programmer->email,
        is_superuser  => $Programmer->is_superuser,
        created_ts    => $Created_Time,
        modified_ts   => $Modified_Time,
        is_deleted    => 0,
      },
    ];
    eq_or_diff $got, $expected, 'matches';
};
