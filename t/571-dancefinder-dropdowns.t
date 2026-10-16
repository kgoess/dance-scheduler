# Tests for DanceFinder->related_entities_for_upcoming_events, the data for
# the dancefinder form's dropdowns

use 5.32.1;
use warnings;

use Data::Dump qw/dump/;
use Data::UUID;
use Test::More tests => 10;

use bacds::Scheduler::Model::DanceFinder;
use bacds::Scheduler::Util::Db qw/get_dbh/;
use bacds::Scheduler::Util::Test qw/setup_test_db/;
use bacds::Scheduler::Util::Time qw/get_today/;

$ENV{TEST_NOW} = 1651112285; # 2022-04-27 19:18:05 Pacific

setup_test_db;
my $dbh = get_dbh();
my $uuid_gen = Data::UUID->new;

sub make_event {
    my (%args) = @_;
    return $dbh->resultset('Event')->create({
        synthetic_name => $args{name},
        start_date => get_today()->add(days => $args{days})->ymd,
        is_deleted => $args{is_deleted} // 0,
        uuid => $uuid_gen->to_string($uuid_gen->create),
    });
}
sub make {
    my ($source, %cols) = @_;
    return $dbh->resultset($source)->create({ is_deleted => 0, %cols });
}

my $today    = make_event(name => 'today',    days => 0);
my $upcoming = make_event(name => 'upcoming', days => 30);
my $past     = make_event(name => 'past',     days => -1);
my $deleted  = make_event(name => 'deleted',  days => 10, is_deleted => 1);

my $o = 1;
# on today's and the upcoming event
my $caller_today    = make('Caller', name => 'Caller Today');
my $caller_upcoming = make('Caller', name => 'Caller Upcoming');
$today->add_to_callers($caller_today, { ordering => $o++ });
$upcoming->add_to_callers($caller_upcoming, { ordering => $o++ });
# on both, should be listed once
my $caller_both = make('Caller', name => 'Caller Both');
$today->add_to_callers($caller_both, { ordering => $o++ });
$upcoming->add_to_callers($caller_both, { ordering => $o++ });
# only on events that shouldn't count
my $caller_past = make('Caller', name => 'Caller Past');
$past->add_to_callers($caller_past, { ordering => $o++ });
my $caller_on_deleted_event = make('Caller', name => 'Caller On Deleted Event');
$deleted->add_to_callers($caller_on_deleted_event, { ordering => $o++ });
# deleted caller on an upcoming event
my $caller_deleted = make('Caller', name => 'Caller Deleted', is_deleted => 1);
$upcoming->add_to_callers($caller_deleted, { ordering => $o++ });
# not on any event
make('Caller', name => 'Caller Unused');

my $venue = make('Venue', vkey => 'HALL', hall_name => 'The Hall', city => 'Berkeley');
$upcoming->add_to_venues($venue, { ordering => 1 });
make('Venue', vkey => 'OTHER', hall_name => 'Other Hall', city => 'Oakland');

my $style = make('Style', name => 'CONTRA');
$upcoming->add_to_styles($style, { ordering => 1 });

my $role_pair = make('RolePair', role_pair => 'Larks and Robins');
$upcoming->add_to_role_pairs($role_pair, { ordering => 1, created_ts => '2022-04-01T00:00:00' });

# musos: one on the event directly, two in a band on the event (one of them
# deleted), and one in a band that's only on a past event
my $band = make('Band', name => 'The Band');
$upcoming->add_to_bands($band, { ordering => 1 });
my $muso_direct  = make('Talent', name => 'Muso Direct');
$upcoming->add_to_talent($muso_direct, { ordering => 1 });
my $muso_in_band = make('Talent', name => 'Muso In Band');
$muso_in_band->add_to_bands($band, { ordering => 1 });
my $muso_deleted = make('Talent', name => 'Muso Deleted', is_deleted => 1);
$muso_deleted->add_to_bands($band, { ordering => 2 });
my $old_band = make('Band', name => 'Old Band');
$past->add_to_bands($old_band, { ordering => 1 });
my $muso_old_band = make('Talent', name => 'Muso Old Band');
$muso_old_band->add_to_bands($old_band, { ordering => 1 });

#
# count the queries, too
#
package QueryCounter {
    our $count = 0;
    sub new { bless {}, shift }
    sub query_start { $count++ }
    sub query_end {}
    sub AUTOLOAD {}
}
$dbh->storage->debugobj(QueryCounter->new);
$dbh->storage->debug(1);
my $data = bacds::Scheduler::Model::DanceFinder->related_entities_for_upcoming_events;
$dbh->storage->debug(0);

sub names {
    my ($hash, $col) = @_;
    $col //= 'name';
    return [ sort map { $_->$col } values %$hash ];
}

is_deeply [ sort keys %$data ], [qw/bands callers musos role_pairs styles venues/],
    'returns all six lists';
is_deeply names($data->{callers}), ['Caller Both', 'Caller Today', 'Caller Upcoming'],
    "callers: today's and upcoming events, once each, no past, deleted-event, deleted or unused ones"
    or dump names($data->{callers});
is_deeply [ sort { $a <=> $b } keys %{ $data->{callers} } ],
          [ sort { $a <=> $b } map $_->caller_id, $caller_today, $caller_upcoming, $caller_both ],
    'keyed by id';
is_deeply names($data->{venues}, 'hall_name'), ['The Hall'], 'venues';
is_deeply names($data->{styles}), ['CONTRA'], 'styles';
is_deeply names($data->{role_pairs}, 'role_pair'), ['Larks and Robins'], 'role pairs';
is_deeply names($data->{bands}), ['The Band'], "bands: not the past event's band";
is_deeply names($data->{musos}), ['Muso Direct', 'Muso In Band'],
    "musos: on the event and in its band, not deleted, not in a past event's band"
    or dump names($data->{musos});
isa_ok $data->{callers}{ $caller_today->caller_id }, 'bacds::Scheduler::Schema::Result::Caller';
is $QueryCounter::count, 6, 'one query per list';
