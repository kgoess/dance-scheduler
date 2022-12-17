use 5.16.0;
use warnings;

use Data::Dump qw/dump/;
use DateTime::Format::Strptime qw/strptime/;
use DateTime;
use JSON::MaybeXS qw/decode_json/;
use Plack::Test;
use Ref::Util qw/is_coderef/;
use Test::Differences qw/eq_or_diff/;
use Test::More tests => 4;

use bacds::Scheduler;
use bacds::Scheduler::Schema;
use bacds::Scheduler::Util::Time qw/get_now/;
use bacds::Scheduler::Util::Db qw/get_dbh/;

use bacds::Scheduler::Util::Test qw/setup_test_db get_tester/;
setup_test_db;
my $test = get_tester(auth => 1);

my $dbh = get_dbh();

my ($Event, $Venued_Event);
my ($Event_Id, $Venued_Event_Id);
my ($Venue_Id, $Venue_Vkey);


# We've already tested POST /event in 200_events.t, so
# this could just use DBIx::Class to insert it directly
subtest 'POST /event' => sub {
    plan tests => 3;

    my ($expected, $created_time, $decoded, $got);

    my $new_event = {
        start_date  => "2022-05-01",
        start_time  => "20:00",
        end_date    => "2022-05-01",
        end_time    => "22:00",
        is_canceled => 1,
        is_template => 0,
        short_desc  => "this is the short desc",
        name        => "saturday night test event",
        series_id   => undef,
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
        is_canceled => $new_event->{is_canceled},
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
        is_template => 0,
    };
    eq_or_diff $got, $expected, 'return matches';

    # now save it for the subsequent tests
    $Event = $dbh->resultset('Event')->find($decoded->{data}{event_id});
    $Event_Id = $Event->event_id;
};


# ******* Now adding venues *******

subtest 'POST /event/# with venues' => sub{
    plan tests => 7;

    my ($new_venue, $decoded, $got, $created_time);

    $new_venue = {
        vkey        => 'VXX',
        hall_name   => 'the hall',
        address     => '123 Sesame St.',
        city        => 'Gotham',
        zip         => '02134',
        directions  => 'how to get here',
        sidebar     => 'stuff in the sidebar',
        programmer_notes => 'blah blah',
        is_deleted  => 0,
    };
    $test->post_ok('/venue/', $new_venue );
    ok($test->success, 'created venue');
    $decoded = decode_json($test->content);
    $Venue_Id = $decoded->{data}{venue_id};
    $Venue_Vkey = $decoded->{data}{vkey};
    $got = {};
    foreach my $key (keys %{$decoded->{data}}){
        $got->{$key} = $decoded->{data}{$key};
    };

    my $expected = {
        venue_id    => $Venue_Id,
        vkey        => $Venue_Vkey,
        hall_name   => $new_venue->{hall_name},
        address     => $new_venue->{address},
        city        => $new_venue->{city},
        zip         => $new_venue->{zip},
        directions         => $new_venue->{directions},
        sidebar         => $new_venue->{sidebar},
        programmer_notes         => $new_venue->{programmer_notes},
        is_deleted  => 0,
        created_ts  => '2022-04-28T02:18:05',
        modified_ts => '2022-04-28T02:18:05',
    };

    eq_or_diff $got, $expected, 'venue return matches';

    my $new_event = {
        start_date  => "2022-05-03",
        start_time  => "20:00",
        end_date    => "2022-05-03",
        end_time    => "22:00",
        is_canceled => 1,
        is_template => 0,
        short_desc   => "this is the short desc",
        name        => "saturday night test event",
        series_id   => undef,
        venue_id   => [$Venue_Id],
        venues     => [
            {
                id => $Venue_Id,
                name  => $Venue_Vkey,
            }
        ],
    };
    $ENV{TEST_NOW} = 1651112285;
    my $now_ts = DateTime
        ->from_epoch(epoch => $ENV{TEST_NOW})
        ->iso8601;
    $test->post_ok('/event/', $new_event );
    ok($test->success, 'returned success');
    $decoded = decode_json($test->content);
    $got = $decoded->{data};

    $Venued_Event_Id = $got->{event_id},

    $expected = {
        venues      => [{
            id   => $Venue_Id,
            name => $Venue_Vkey,
        }],
    };

    is $got->{event_id}, $Venued_Event_Id, "that's the right event";
    eq_or_diff $got->{venues}, $expected->{venues}, 'return matches';

    $Venued_Event = $dbh->resultset('Event')->find($Venued_Event_Id);
};

subtest "GET /event/# with venues" => sub {
    plan tests => 4;

    my ($expected, $decoded, $got);

    $test->get_ok("/event/$Venued_Event_Id" );
    ok( $test->success, 'returned success' );
    $decoded = decode_json($test->content);
    $got = $decoded->{data};
    $expected = {
        venues      => [{
            id   => $Venue_Id,
            name => $Venue_Vkey,
        }],
    };

    is $got->{event_id}, $Venued_Event_Id, "that's the right event";
    eq_or_diff $got->{venues}, $expected->{venues}, 'return matches';
};


subtest "PUT /event/# with venues" => sub {
    plan tests => 8;

    my ($expected, $created_time, $modified_time, $decoded, $got);

    my $other_venue = {
        vkey        => 'VZZ',
        hall_name   => 'the hall',
        address     => '123 Sesame St.',
        city        => 'Gotham',
        zip         => '02134',
        comment     => 'this is the comment',
        is_deleted  => 0,
    };
    $test->post_ok('/venue/', $other_venue );
    ok($test->success, 'created venue') or die $test->content;

    $decoded = decode_json($test->content);
    my $other_venue_id = $decoded->{data}{venue_id};

    my $edit_event = {
        start_date  => "2022-05-03",
        start_time  => "21:00",
        end_date    => "2022-05-03",
        end_time    => "23:00",
        is_canceled     => 0,
        short_desc   => "this is a new short desc",
        name        => "new name",
        venue_id    => [$Venue_Id, $other_venue_id],
        style_id   => [],
    };
    $ENV{TEST_NOW} += 100;
    $modified_time = get_now();
    $test->put_ok("/event/$Venued_Event_Id" , {content => $edit_event});
    ok( $test->success, 'returned success' ) or die $test->content;
    $decoded = decode_json($test->content);
    $got = $decoded->{data};
    $expected = {
        venues      => [
            {
                id => 1,
                name => 'VXX',
            },
            {
                id => 2,
                name => 'VZZ',
            }
        ],
    };
    is $got->{event_id}, $Venued_Event_Id, "that's the right event";
    eq_or_diff $got->{venues}, $expected->{venues}, 'return matches';

    $test->get_ok("/event/$Venued_Event_Id" );
    $decoded = decode_json($test->content);
    $got = $decoded->{data};

    eq_or_diff $got->{venues}, $expected->{venues}, 'GET changed after PUT';
};


