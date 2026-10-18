# Tests for the Event->ordered_* accessors, and that the public listings
# don't run a query per event (they used to call
# event.bands({}, { order_by => 'me.ordering' }) and friends, which ignore
# the prefetched rows)

use 5.32.1;
use warnings;

use Data::Dump qw/dump/;
use Data::UUID;
use HTTP::Request::Common;
use Test::More tests => 15;

use bacds::Scheduler::Model::DanceFinder;
use bacds::Scheduler::Util::Db qw/get_dbh/;
use bacds::Scheduler::Util::Test qw/setup_test_db get_tester/;
use bacds::Scheduler::Util::Time qw/get_now/;

$ENV{TEST_NOW} = 1651112285; # 2022-04-27 19:18:05

setup_test_db;
my $dbh = get_dbh();

# counts the SQL statements run while it's installed
package QueryCounter {
    our $count = 0;
    sub new { bless {}, shift }
    sub query_start { $count++ }
    sub query_end {}
    sub AUTOLOAD {}
}
$dbh->storage->debugobj(QueryCounter->new);
sub count_queries {
    my ($code) = @_;
    local $QueryCounter::count = 0;
    $dbh->storage->debug(1);
    $code->();
    $dbh->storage->debug(0);
    return $QueryCounter::count;
}

my $uuid_gen = Data::UUID->new;
my $bacds = $dbh->resultset('ParentOrg')->create({ full_name => 'BACDS', abbreviation => 'BACDS' });
my $contra  = $dbh->resultset('Style')->create({ name => 'CONTRA' });
my $english = $dbh->resultset('Style')->create({ name => 'ENGLISH' });
my $venue   = $dbh->resultset('Venue')->create({ vkey => 'HALL', hall_name => 'The Hall', city => 'Berkeley' });

my $n = 0;
sub make_event {
    my ($days_from_now) = @_;
    $n++;
    my $event = $dbh->resultset('Event')->create({
        name => "event $n", synthetic_name => "event $n",
        start_date => get_now()->add(days => $days_from_now)->ymd,
        start_time => '20:00:00',
        uuid => $uuid_gen->to_string($uuid_gen->create),
    });
    $event->add_to_parent_orgs($bacds, { ordering => 1 });
    $event->add_to_venues($venue, { ordering => 1 });
    # added in the opposite order to their "ordering"
    $event->add_to_styles($english, { ordering => 2 });
    $event->add_to_styles($contra,  { ordering => 1 });
    for my $i (reverse 1 .. 2) {
        my $band = $dbh->resultset('Band')->create({ name => "band $n.$i" });
        $event->add_to_bands($band, { ordering => $i });
        my $caller = $dbh->resultset('Caller')->create({ name => "caller $n.$i" });
        $event->add_to_callers($caller, { ordering => $i });
        my $talent = $dbh->resultset('Talent')->create({ name => "muso $n.$i" });
        $event->add_to_talent($talent, { ordering => $i });
    }
    return $event;
}

my $event = make_event(1);

#
# ordering
#
is_deeply [ map $_->name, $event->ordered_styles ], ['CONTRA', 'ENGLISH'],
    'ordered_styles follows the mapping table ordering, not insertion order';
is_deeply [ map $_->name, $event->ordered_bands ], ['band 1.1', 'band 1.2'], 'ordered_bands';
is_deeply [ map $_->name, $event->ordered_callers ], ['caller 1.1', 'caller 1.2'], 'ordered_callers';
is_deeply [ map $_->name, $event->ordered_talent ], ['muso 1.1', 'muso 1.2'], 'ordered_talent';
is_deeply [ map $_->hall_name, $event->ordered_venues ], ['The Hall'], 'ordered_venues';
is_deeply [ $event->ordered_teams ], [], 'ordered_teams with no teams';
is ref(scalar $event->ordered_bands), 'ARRAY', 'arrayref in scalar context';

is_deeply [ map $_->name, $event->ordered_bands ],
          [ map $_->name, $event->bands({}, { order_by => 'me.ordering' }) ],
          'same as the old order_by query';

#
# no queries for prefetched events
#
my @events = bacds::Scheduler::Model::DanceFinder->search_events->all;
is scalar(@events), 1, 'search_events found the event';
my $queries = count_queries(sub {
    for my $e (@events) {
        my @x = ($e->ordered_bands, $e->ordered_callers, $e->ordered_talent,
                 $e->ordered_styles, $e->ordered_venues, $e->ordered_teams,
                 $e->ordered_parent_orgs, $e->ordered_role_pairs);
        $_->name for grep { $_->can('name') } @x;
    }
});
is $queries, 0, 'the ordered_* accessors make no queries on events from search_events';

#
# the pages don't make a query per event
#
my $test = get_tester();
my %queries_for;
for my $url ('/unearth', '/dancefinder-results?style=' . $contra->style_id) {
    # the first request does some one-time lookups (e.g. /unearth caches
    # the SPECIAL and CAMP style ids), so don't count that one
    $test->get_ok($url);
    $queries_for{$url}{1} = count_queries(sub { $test->get($url) });
}
make_event($_) for 2 .. 6;
for my $url ('/unearth', '/dancefinder-results?style=' . $contra->style_id) {
    $queries_for{$url}{6} = count_queries(sub { $test->get($url) });
    is $queries_for{$url}{6}, $queries_for{$url}{1},
        "$url: same number of queries for 6 events as for 1 ($queries_for{$url}{1})";
}
like $test->content, qr{band 6\.1.*band 6\.2}s, 'and the listing shows the bands in order';
