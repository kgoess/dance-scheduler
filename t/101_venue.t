use 5.16.0;
use warnings;

use Data::Dump qw/dump/;
use DateTime;
use DateTime::Format::Strptime qw/strptime/;
use JSON qw/decode_json/;
use HTTP::Request::Common;
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

my ($Venue, $Venue_Id);

subtest 'Invalid GET /venue/1' => sub{
    plan tests=>2;
    my ($res, $decoded, $expected);

    $res = $test->request( GET '/venue/1' );
    ok($res->is_success, 'returned success');
    $decoded = decode_json($res->content);
    $expected = {
        errors => [{
            msg => 'Nothing Found for venue_id 1',
            num => 1700,
        }]
    };
    is_deeply $decoded, $expected, 'error msg matches';
};

subtest 'POST /venue' => sub{
    plan tests=>2;
    my ($res, $decoded, $expected, $got);

    my $new_venue = {
        name       => 'ABC', # this is "vkey" in the schema
        hall_name  => 'test venue name',
        address    => 'test address',
        city       => 'test city',
        zip        => '12345-1234',
        comment    => 'test comment',
        is_deleted => 0,
    };
    $ENV{TEST_NOW} = 1651112285;
    $res = $test->request(POST '/venue/', $new_venue);
    ok($res->is_success, 'returned success');
    $decoded = decode_json($res->content);
    $got = $decoded->{data};
    $expected = {
        venue_id    => 1,
        vkey        => $new_venue->{name}, # FIXME conflating vkey and name
        name        => $new_venue->{name},
        hall_name   => $new_venue->{hall_name},
        address     => $new_venue->{address},
        city        => $new_venue->{city},
        zip         => $new_venue->{zip},
        comment     => $new_venue->{comment},
        is_deleted  => $new_venue->{is_deleted},
        created_ts  => "2022-04-28T02:18:05",
        modified_ts => "2022-04-28T02:18:05",
        is_deleted  => 0, # FIXME is that right? test 1
    };
    eq_or_diff $got, $expected, 'return matches';

    # now save it for the subsequent tests
    $Venue = $dbh->resultset('Venue')->find($decoded->{data}{venue_id});
    $Venue_Id = $Venue->venue_id;
};


subtest 'GET /venue/#' => sub {
    plan tests=>2;
    my ($res, $decoded, $got, $expected);

    $res = $test->request( GET "/venue/$Venue_Id" );
    ok( $res->is_success, 'returned success' );
    $decoded = decode_json($res->content); 
    $got = $decoded->{data};
    $expected = {
        venue_id    => 1,
        vkey        => $Venue->vkey, # FIXME conflating vkey and name
        name        => $Venue->vkey,
        hall_name   => $Venue->hall_name,
        address     => $Venue->address,
        city        => $Venue->city,
        zip         => $Venue->zip,
        comment     => $Venue->comment,
        is_deleted   => $Venue->is_deleted,
        created_ts  => "2022-04-28T02:18:05",
        modified_ts => "2022-04-28T02:18:05",
    };

    eq_or_diff $got, $expected, 'matches';
};


subtest 'PUT /venue/1' => sub {
    plan tests => 4;
    my ($expected, $res, $decoded, $got);

    $ENV{TEST_NOW} += 100;

    my $edit_venue = {
        name       => 'BCD',
        hall_name  => 'test change name',
        address    => 'test new address',
        city       => 'test altered city',
        zip        => '54321-1234',
        comment    => 'test different comment',
        is_deleted => 1,
    };
    $res = $test->request( PUT '/venue/1' , content => $edit_venue);
    ok( $res->is_success, 'returned success' );
    $decoded = decode_json($res->content);

    $expected = {
        venue_id    => 1,
        vkey        => $edit_venue->{name}, # FIXME conflating vkey and name
        name        => $edit_venue->{name},
        hall_name   => $edit_venue->{hall_name},
        address     => $edit_venue->{address},
        city        => $edit_venue->{city},
        zip         => $edit_venue->{zip},
        comment     => $edit_venue->{comment},
        is_deleted  => 1,
        created_ts  => "2022-04-28T02:18:05",
        modified_ts => "2022-04-28T02:19:45",
    };

    $got = $decoded->{data};
    eq_or_diff $got, $expected, 'matches';

    $res  = $test->request( GET '/venue/1' );
    $decoded = decode_json($res->content); 
    $got = $decoded->{data};
    eq_or_diff $got, $expected, 'GET changed after PUT';

    # update our global venue object
    # reset it so the next test can find it
    $edit_venue->{is_deleted} = 0;
    $res = $test->request( PUT '/venue/1' , content => $edit_venue);
    ok( $res->is_success, 'returned success' );

    $Venue = $dbh->resultset('Venue')->find($decoded->{data}{venue_id});

};

subtest 'GET /venueAll' => sub {
    plan tests => 2;
    my ($res, $expected, $decoded, $got);

    $res  = $test->request( GET '/venueAll' );
    ok( $res->is_success, 'Returned success' );
    $decoded = decode_json($res->content);
    $got = $decoded->{data};
    $expected = [
        {
            venue_id    => 1,
            vkey        => 'BCD',
            name        => 'BCD',
            hall_name   => $Venue->hall_name,
            address     => $Venue->address,
            city        => $Venue->city,
            zip         => $Venue->zip,
            comment     => $Venue->comment,
            is_deleted  => $Venue->is_deleted,
            created_ts  => "2022-04-28T02:18:05",
            modified_ts => "2022-04-28T02:19:45",
        }
    ];

    eq_or_diff $got, $expected, 'matches';
};
