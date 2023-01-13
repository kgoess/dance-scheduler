use 5.16.0;
use warnings;

use Data::Dump qw/dump/;
use DateTime;
use DateTime::Format::Strptime qw/strptime/;
use JSON::MaybeXS qw/decode_json/;
use HTTP::Request::Common;
use Plack::Test;
use Ref::Util qw/is_coderef/;

use Test::Differences qw/eq_or_diff/;
use Test::More tests => 6;
use Test::Warn;

use bacds::Scheduler;
use bacds::Scheduler::Schema;
use bacds::Scheduler::Util::Time qw/get_now/;
use bacds::Scheduler::Util::Db qw/get_dbh/;

use bacds::Scheduler::Util::Test qw/setup_test_db get_tester/;
setup_test_db;

my $app = bacds::Scheduler->to_app;
my $test = get_tester(auth => 1);
my $dbh = get_dbh();

my ($Venue, $Venue_Id);

subtest 'Invalid GET /venue/1' => sub{
    plan tests=>2;
    my ($res, $decoded, $expected);

    $res = $test->request( GET '/venue/1' );
    ok($res->is_success, 'returned success');
    $decoded = decode_json($res->content);
    $expected = {
        data => '',
        errors => [{
            msg => 'Nothing found for Venue: primary key "1"',
            num => 404,
        }]
    };
    is_deeply $decoded, $expected, 'error msg matches';
};

subtest 'POST /venue' => sub {
    plan tests=>2;
    my ($res, $decoded, $expected, $got);

    my $new_venue = {
        venue_id           => '', # This should be ignored by the model
        vkey               => 'ABC', # this is "vkey" in the schema
        hall_name          => 'test venue name',
        address            => 'test address',
        city               => 'test city',
        zip                => '12345-1234',
        programmer_notes    => 'test note',
        directions         => 'test directions',
        sidebar            => 'test sidebar',
        is_deleted         => 0,
        # the webapp doesn't have a problem with venue_id here like the other
        # models, not sure why
    };
    $ENV{TEST_NOW} = 1651112285;
    $res = $test->request(POST '/venue/', $new_venue);
    ok($res->is_success, 'returned success');
    $decoded = decode_json($res->content);
    $got = $decoded->{data};
    $expected = {
        venue_id             => 1,
        vkey                 => $new_venue->{vkey},
        hall_name            => $new_venue->{hall_name},
        address              => $new_venue->{address},
        city                 => $new_venue->{city},
        zip                  => $new_venue->{zip},
        programmer_notes     => $new_venue->{programmer_notes},
        directions           => $new_venue->{directions},
        sidebar              => $new_venue->{sidebar},
        is_deleted           => $new_venue->{is_deleted},
        created_ts           => "2022-04-28T02:18:05",
        modified_ts          => "2022-04-28T02:18:05",
        is_deleted           => 0,
    };
    eq_or_diff $got, $expected, 'return matches';

    # now save it for the subsequent tests
    $Venue = $dbh->resultset('Venue')->find($decoded->{data}{venue_id});
    $Venue_Id = $Venue->venue_id;

};

subtest 'POST /venue duplicate' => sub {
    plan tests => 3;

    my ($expected, $res, $decoded, $got);
    my $dup_venue = {
        venue_id           => '', # the webapp sends name=test+venue&venue_id=
        vkey               => 'ABC', # this is "vkey" in the schema
        hall_name          => 'test venue name',
    };
    $ENV{TEST_NOW} = 1651112285;
    local $ENV{TEST_DUP_VALUE} = 'ABC';
    warning_is {
        $res = $test->request(POST '/venue/', $dup_venue );
    } 'UNIQUE constraint failed: venues.vkey: ABC';

    ok($res->is_success, 'still a 200-OK though');

    $got = decode_json($res->content);
    $expected = {
        data   => "",
        errors => [ {
            msg => "There is already an entry for 'ABC' under Venue",
            num => 409,
          },
        ],
    };
    eq_or_diff $got, $expected, 'return matches';
};


subtest 'GET /venue/#' => sub {
    plan tests=>2;
    my ($res, $decoded, $got, $expected);

    $res = $test->request( GET "/venue/$Venue_Id" );
    ok( $res->is_success, 'returned success' );
    $decoded = decode_json($res->content); 
    $got = $decoded->{data};
    $expected = {
        venue_id         => 1,
        vkey             => $Venue->vkey,
        hall_name        => $Venue->hall_name,
        address          => $Venue->address,
        city             => $Venue->city,
        zip              => $Venue->zip,
        programmer_notes => $Venue->programmer_notes,
        directions       => $Venue->directions,
        sidebar          => $Venue->sidebar,
        is_deleted       => $Venue->is_deleted,
        created_ts       => "2022-04-28T02:18:05",
        modified_ts      => "2022-04-28T02:18:05",
    };

    eq_or_diff $got, $expected, 'matches';
};


subtest 'PUT /venue/1' => sub {
    plan tests => 6;
    my ($expected, $res, $decoded, $got);

    $ENV{TEST_NOW} += 100;

    my $edit_venue = {
        vkey                => 'BCD',
        hall_name           => 'test change name',
        address             => 'test new address',
        city                => 'test altered city',
        zip                 => '54321-1234',
        programmer_notes    => 'test different comment',
        directions          => 'new directions',
        sidebar             => 'new sidebar',
        is_deleted          => 1,
    };
    $res = $test->request( PUT '/venue/1' , content => $edit_venue);
    ok( $res->is_success, 'returned success' );
    $decoded = decode_json($res->content);

    $expected = {
        venue_id          => 1,
        vkey              => $edit_venue->{vkey},
        hall_name         => $edit_venue->{hall_name},
        address           => $edit_venue->{address},
        city              => $edit_venue->{city},
        zip               => $edit_venue->{zip},
        programmer_notes  => $edit_venue->{programmer_notes},
        directions        => $edit_venue->{directions},
        sidebar           => $edit_venue->{sidebar},
        is_deleted        => 1,
        created_ts        => "2022-04-28T02:18:05",
        modified_ts       => "2022-04-28T02:19:45",
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


    # demonstrate behavior on PUT with a non-existent pkey
    $test->put_ok('/venue/45789', { content => $edit_venue })
        or die $test->res->content;
    $decoded = decode_json($test->res->content);
    is $decoded->{errors}[0]{msg}, 'Nothing found for Venue: primary key "45789"',
        'failed PUT has expected error msg' or diag explain $decoded;

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
            venue_id         => 1,
            vkey             => 'BCD',
            hall_name        => $Venue->hall_name,
            address          => $Venue->address,
            city             => $Venue->city,
            zip              => $Venue->zip,
            programmer_notes => $Venue->programmer_notes,
            directions       => $Venue->directions,
            sidebar          => $Venue->sidebar,
            is_deleted       => $Venue->is_deleted,
            created_ts       => "2022-04-28T02:18:05",
            modified_ts      => "2022-04-28T02:19:45",
        }
    ];

    eq_or_diff $got, $expected, 'matches';
};
