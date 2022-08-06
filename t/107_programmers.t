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
use Test::More tests => 8;

use bacds::Scheduler;
use bacds::Scheduler::Schema;
use bacds::Scheduler::Util::Time qw/get_now/;
use bacds::Scheduler::Util::Db qw/get_dbh/;

use bacds::Scheduler::Util::TestDb qw/setup_test_db/;
setup_test_db;

my $app = bacds::Scheduler->to_app;
my $test = Plack::Test->create($app);
my $dbh = get_dbh();

my $Programmer;
my $Programmer_Id;
my $Programmer_With_Series;
my $Programmer_With_Series_Id;
my $Created_Time;
my $Modified_Time;
my $Modified_Time_With_Series;


my $Series1 = $dbh->resultset('Series')->new({
    name => 'test series 1',
});
$Series1->insert;
my $Series2 = $dbh->resultset('Series')->new({
    name => 'test series 1',
});
$Series2->insert;
my $Series3 = $dbh->resultset('Series')->new({
    name => 'test series 3',
});
$Series3->insert;


subtest 'Invalid GET /programmer/1' => sub{
    plan tests=>2;

    my ($res, $decoded, $got, $expected);
    $res = $test->request( GET '/programmer/1' );
    ok($res->is_success, 'returned success');

    $decoded = decode_json($res->content);
    $expected = {
        data => '',
        errors => [{
            msg => 'Nothing Found for programmer_id 1',
            num => 3200,
        }]
    };
    eq_or_diff $decoded, $expected, 'error msg matches';
};

subtest 'POST /programmer' => sub{
    plan tests=>2;

    my ($expected, $res, $decoded, $got);
    my $new_programmer = {
        name          => 'alice programmer',
        email         => 'alice@test.com',
        password_hash => 'thisisthepasswordhash',
        is_superuser  => 1,
        programmer_id => '', # the webapp sends name=test+programmer&programmer_id=
    };
    $ENV{TEST_NOW} = 1651112285;
    $Created_Time = get_now()->iso8601;
    $res = $test->request(POST '/programmer/', $new_programmer );
    ok($res->is_success, 'returned success');

    $decoded = decode_json($res->content);
    $got = $decoded->{data};
    $expected = {
        programmer_id    => 1,
        name         => $new_programmer->{name},
        email        => $new_programmer->{email},
        is_superuser => $new_programmer->{is_superuser},
        created_ts   => $Created_Time,
        modified_ts  => $Created_Time,
        series       => [],
        is_deleted   => 0,
    };
    eq_or_diff $got, $expected, 'return matches';

    # now save it for the subsequent tests
    $Programmer = $dbh->resultset('Programmer')->find($decoded->{data}{programmer_id});
    $Programmer_Id = $Programmer->programmer_id;
};

subtest 'POST /programmer with series' => sub{
    plan tests=>2;

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
        programmer_id => 2,
        name          => $new_programmer->{name},
        email         => $new_programmer->{email},
        is_superuser  => $new_programmer->{is_superuser},
        created_ts    => $Created_Time,
        modified_ts   => $Created_Time,
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
        is_deleted   => 0,
    };
    eq_or_diff $got, $expected, 'return matches';

    # now save it for the subsequent tests
    $Programmer_With_Series = $dbh->resultset('Programmer')->find($decoded->{data}{programmer_id});
    $Programmer_With_Series_Id = $Programmer_With_Series->programmer_id;
};

subtest 'GET /programmer/1' => sub{
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
        series         => [],
    };
    eq_or_diff $got, $expected, 'return matches';
};

subtest 'GET /programmer/2 (with series)' => sub{
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
    };
    eq_or_diff $got, $expected, 'return matches';
};


subtest 'PUT /programmer/#' => sub {
    plan tests => 3;

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
        is_superuser  => undef,
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
        series => [
            {
                id => $Series3->series_id,
                name => $Series3->name,
            },
        ],
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



subtest 'GET /programmerAll' => sub{
    plan tests => 2;

    my ($res, $decoded, $got, $expected);
    $res  = $test->request( GET '/programmerAll' );
    ok( $res->is_success, 'Returned success' );

    $decoded = decode_json($res->content);
    $got = $decoded->{data};
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
