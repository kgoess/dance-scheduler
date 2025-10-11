
use 5.16.0;
use warnings;

# this tests dancefinder and livecalendar and serieslister, both the backend
# and the url endpoints

use Data::Dump qw/dump/;
use JSON::MaybeXS qw/decode_json/;
use Test::Differences qw/eq_or_diff/;

use Test::More tests => 1;

use bacds::Scheduler::Util::Db qw/get_dbh/;
use bacds::Scheduler::Util::Test qw/setup_test_db get_tester/;
use bacds::Scheduler::Util::Time qw/get_today/;

use bacds::Scheduler::Model::DanceFinder;

setup_test_db;

my $Test = get_tester(auth => 1);

my $dbh = get_dbh();

$ENV{TEST_NOW} = 1651112285; # 2022-04-27 19:18:05

my $dtf = $dbh->storage->datetime_parser;

my $event1 = $dbh->resultset('Event')->new({
    name => 'test event 1',
    synthetic_name => 'test event 1 synthname',
    custom_url => 'http://custom-url/test-event-1',
    short_desc => 'big <b> dance party &#9786',
    start_date => $dtf->format_datetime(get_today->truncate(to=>'day')),
    start_time => '18:00:00',
});
$event1->insert;

my $rs = bacds::Scheduler::Model::DanceFinder
    ->search_events();

my @events = $rs->all;

is @events, 1, 'event found with no args';