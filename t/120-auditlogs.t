
use 5.16.0;
use warnings;
use utf8;
use open ':std', ':encoding(utf8)'; # "wide character in print" warnings from test fails

# tests the audit_logs table updates for create/POST and update/PUT requests

use Data::Dump qw/dump/;
use Data::UUID;
use JSON::MaybeXS qw/decode_json/;
use Test::Differences qw/eq_or_diff/;
use Test::More tests => 41;

use bacds::Scheduler::Util::Db qw/get_dbh/;
use bacds::Scheduler::Util::Test qw/setup_test_db get_tester/;
use bacds::Scheduler::Util::Time qw/get_now/;

use bacds::Scheduler::Model::DanceFinder;
use bacds::Scheduler::Model::SeriesLister;
use bacds::Scheduler::Model::Calendar;

setup_test_db;

my $test = get_tester(auth => 1);

my $dbh = get_dbh();

$ENV{TEST_NOW} = 1651112285; # 2022-04-27

my $i = 0;

my $fixture = setup_fixture();
test_create($test);
test_update($test, $fixture);
test_update_start_end_dates($test, $fixture);

sub setup_fixture {

    my $event1 = $dbh->resultset('Event')->new({
        name => 'test event 1',
        synthetic_name => 'test event 1 synthname',
        custom_url => 'http://custom-url/test-event-1',
        short_desc => 'big <b> dance party &#9786',
        start_date => get_now->ymd('-'),
        start_time => '20:00',
        uuid => uuid(),
    });
    $event1->insert;

    my $band1 = $dbh->resultset('Band')->new({
        name => 'test band 1',
    });
    $band1->insert;
    $band1->add_to_events($event1, {
        ordering => $i++,
         created_ts => '2022-07-31T13:33',
    });

    my $muso1 = $dbh->resultset('Talent')->new({
        name => 'muso 1',
    });
    $muso1->insert;
    # the web UI actually adds the band's current talent to the event as their
    # own musos, but by not doing that I can test that our SELECT statements
    # fetch all the related data even if it doesn't match the search terms.
    $muso1->add_to_bands($band1, {
         ordering => $i++,
         created_ts => '2022-07-31T13:33',
    });

    # just to bump the IDs past 1
    my $style0 = $dbh->resultset('Style')->new({
        name => 'CAMP',
    });
    $style0->insert;

    my $style1 = $dbh->resultset('Style')->new({
        name => 'ENGLISH',
    });
    $style1->insert;
    $style1->add_to_events($event1, {
        ordering => $i++,
        created_ts => '2022-04-01T13:33',
    });
    my $style2 = $dbh->resultset('Style')->new({
        name => 'CONTRA',
    });
    $style2->insert;

    my $caller1 = $dbh->resultset('Caller')->new({
        name => 'Alice Ackerby',
    });
    $caller1->insert;
    $caller1->add_to_events($event1, {
        ordering => $i++,
        created_ts => '2022-04-01T13:33',
    });

    my $venue1 = $dbh->resultset('Venue')->new({
        vkey => 'hop',
        hall_name => "Mr. Hooper's Store",
        address => '123 Sesame St.',
        city => 'Sunny Day',
    });
    $venue1->insert;
    $venue1->add_to_events($event1, {
        ordering => $i++,
        created_ts => '2022-04-01T13:33',
    });


    my $series1 = $dbh->resultset('Series')->new({
        name => "The Dance-A-Week Series",
        series_xid => 'DAW',
        series_url => "https://bacds.org/dance-a-week/",
    });
    $series1->insert;

    $event1->series_id($series1->series_id);
    $event1->update;

    return {
        event1 => $event1->event_id,
        band1 => $band1->band_id,
        caller1 => $caller1->caller_id,
        muso1 => $muso1->talent_id,
        style1 => $style1->style_id,
        style2 => $style2->style_id,
        venue1 => $venue1->venue_id,
        series1 => $series1->series_id,
    }
}


# not a complete test
sub test_create {
    my ($test) = @_;

    my $new_event = {
        start_date  => "2022-05-01",
        start_time  => "20:00",
        end_date    => "2022-05-01",
        end_time    => "22:00",
        short_desc  => "itsa shortdesc",
        name        => "saturday night 無為",
        style_id    => undef,
        and_friends => 0,
        is_canceled => 0,
        is_series_defaults => 0,
    };
    $test->post_ok('/event/', $new_event );

    my $log = get_most_recent_log();

    is $log->programmer_id, 1;
    is $log->target, 'Event';
    is $log->target_id, 2; # this one plus the one in the fixture
    is $log->action, 'create';
    is $log->message, 'created Event "saturday night 無為"';
}
sub test_update {
    my ($test, $fixture) = @_;

    my $update= {
        band_id => $fixture->{band1},
        caller_id => $fixture->{caller1},
        style_id =>  $fixture->{style1},
        venue_id => $fixture->{venue1},
    };
    $update->{name} = 'good times 派对';
    $test->put_ok("/event/$fixture->{event1}", { content => $update } );

    my $log = get_most_recent_log();

    is $log->programmer_id, 1;
    is $log->target, 'Event';
    is $log->target_id, $fixture->{event1};
    is $log->action, 'update';
    is $log->message, 'name to "good times 派对"';

    #
    # hit that again, no change, nothing dirty, shouldn't log
    #
    $test->put_ok("/event/$fixture->{event1}", { content => $update } );
    is get_most_recent_log()->audit_log_id, $log->audit_log_id;

    #
    # utf8 test, unrelated field shouldn't change the utf8 data
    #
    $update->{start_date} = '2022-12-30';
    $update->{end_date} = '2022-12-31';
    $test->put_ok("/event/$fixture->{event1}", { content => $update } );
    $log = get_most_recent_log();
    is $log->programmer_id, 1;
    is $log->target, 'Event';
    is $log->target_id, $fixture->{event1};
    is $log->action, 'update';
    is $log->message, 'start_date to "2022-12-30", end_date to "2022-12-31"';

    #
    # testing related tables, add a style
    #
    $update->{style_id} = [ $fixture->{style1}, $fixture->{style2} ];

    $test->put_ok("/event/$fixture->{event1}", { content => $update } );
    $log = get_most_recent_log();
    is $log->programmer_id, 1;
    is $log->target, 'Event';
    is $log->target_id, $fixture->{event1};
    is $log->action, 'update';
    is $log->message, 'styles to "CONTRA, ENGLISH"';

    #
    # take out a style
    #
    $update->{style_id} = [ $fixture->{style2} ];

    $test->put_ok("/event/$fixture->{event1}", { content => $update } );
    $log = get_most_recent_log();
    is $log->programmer_id, 1;
    is $log->target, 'Event';
    is $log->target_id, $fixture->{event1};
    is $log->action, 'update';
    is $log->message, 'styles to "CONTRA"';
}

# trying to get the string handling right. the js app sends end_date as an
# empty string even if there's no value
sub test_update_start_end_dates {
    my ($test, $fixture) = @_;

    my ($update, $log);

    #
    # start with a good zero state
    #
    $update= {
        name => 'good times 派对',
        start_date => '',
        end_date => '',
    };
    $test->put_ok("/event/$fixture->{event1}", { content => $update } );

    #
    # set the start date
    #
    $update= {
        name => 'good times 派对',
        start_date => '2022-01-01',
        end_date => '',
    };
    $test->put_ok("/event/$fixture->{event1}", { content => $update } );
    $log = get_most_recent_log();
    is $log->message, 'start_date to "2022-01-01"';

    #
    # set the end date
    #
    $update= {
        name => 'good times 派对',
        start_date => '2022-01-01',
        end_date => '2022-01-05',
    };
    $test->put_ok("/event/$fixture->{event1}", { content => $update } );
    $log = get_most_recent_log();
    is $log->message, 'end_date to "2022-01-05"';

    #
    # un-set the end date
    #
    $update= {
        name => 'good times 派对',
        start_date => '2022-01-01',
        end_date => '',
    };
    $test->put_ok("/event/$fixture->{event1}", { content => $update } );
    $log = get_most_recent_log();
    is $log->message, 'end_date to ""';

    #
    # change the name, end_date shouldn't change
    #
    $update= {
        name => 'Володимир Зеленський',
        start_date => '2022-01-01',
        end_date => '',
    };
    $test->put_ok("/event/$fixture->{event1}", { content => $update } );
    $log = get_most_recent_log();
    is $log->message, 'name to "Володимир Зеленський"';
}

sub get_most_recent_log {

    my $dbh = get_dbh();
    my $rs = $dbh->resultset('AuditLog')->search(undef, {});
    my $most_recent = $rs->get_column('audit_log_id')->max();

    $rs = $dbh->resultset('AuditLog')->find($most_recent);
}

sub uuid {
    state $uuid_gen = Data::UUID->new;
    return $uuid_gen->to_string($uuid_gen->create);
}
