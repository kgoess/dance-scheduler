
use 5.16.0;
use warnings;

# Adding "start_time" to the "order_by" in search_events, let's verify it
# works. Easiest to set up a fresh test fixture in a separate file.

use Data::Dump qw/dump/;
use JSON::MaybeXS qw/decode_json/;
use Test::Differences qw/eq_or_diff/;
use Test::More tests => 5;

use bacds::Scheduler::Util::Db qw/get_dbh/;
use bacds::Scheduler::Util::Test qw/setup_test_db get_tester/;
use bacds::Scheduler::Util::Time qw/get_now/;

use bacds::Scheduler::Model::DanceFinder;
use bacds::Scheduler::Model::SeriesLister;
use bacds::Scheduler::Model::Calendar;

setup_test_db;

my $Test = get_tester(auth => 1);

my $dbh = get_dbh();

$ENV{TEST_NOW} = 1651112285; # 2022-04-27

my $i = 0;

my $fixture = setup_fixture();
test_search_events($fixture);

sub setup_fixture {

    # no start_time set
    my $event1 = $dbh->resultset('Event')->new({
        name => 'event without start time',
        start_date => get_now->ymd('-'),
        start_time => '',
    });
    $event1->insert;
    # one at 14:00
    my $event2 = $dbh->resultset('Event')->new({
        name => 'event at 14:00',
        start_date => get_now->ymd('-'),
        start_time => '14:00',
    });
    # one at 15:00
    $event2->insert;
    my $event3 = $dbh->resultset('Event')->new({
        name => 'event at 15:00',
        start_date => get_now->ymd('-'),
        start_time => '15:00',
    });
    $event3->insert;
    # and one with an earlier time to make sure we're not getting the database
    # order by default
    my $event4 = $dbh->resultset('Event')->new({
        name => 'event at 13:00',
        start_date => get_now->ymd('-'),
        start_time => '13:00',
    });
    $event4->insert;

    return {
        event1 => $event1->event_id,
        event2 => $event2->event_id,
        event3 => $event3->event_id,
        event4 => $event4->event_id,
    }
}


sub test_search_events {
    my ($fixture) = @_;

    my ($rs, @events);

    $rs = bacds::Scheduler::Model::DanceFinder
        ->search_events();

    @events = $rs->all;

    is @events, 4, 'four events found';

    is $events[0]->name, 'event without start time';
    is $events[1]->name, 'event at 13:00';
    is $events[2]->name, 'event at 14:00';
    is $events[3]->name, 'event at 15:00';


}
