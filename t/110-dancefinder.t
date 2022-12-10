
use 5.16.0;
use warnings;

use Data::Dump qw/dump/;
use JSON::MaybeXS qw/decode_json/;
use Test::Differences qw/eq_or_diff/;
use Test::More tests => 26;

use bacds::Scheduler::Util::Db qw/get_dbh/;
use bacds::Scheduler::Util::Test qw/setup_test_db get_tester/;
use bacds::Scheduler::Util::Time qw/get_now/;

use bacds::Scheduler::Model::DanceFinder;

setup_test_db;

my $Test = get_tester(auth => 1);

my $dbh = get_dbh();

$ENV{TEST_NOW} = 1651112285; # 2022-04-27

my $i = 0;

my $fixture = setup_fixture();
test_model_related_entities();
test_dancefinder_endpoint();
test_search_events($fixture);
test_livecalendar_endpoint($fixture);

sub setup_fixture {

    my $event1 = $dbh->resultset('Event')->new({
        name => 'test event 1',
        synthetic_name => 'test event 1 synthname',
        start_date => get_now->ymd('-'),
        start_time => '20:00',
    });
    $event1->insert;
    my $event2 = $dbh->resultset('Event')->new({
        name => 'test event 2',
        synthetic_name => 'test event 2 synthname',
        start_date => get_now->ymd('-'),
        start_time => '20:00',
    });
    $event2->insert;

    # this one is before today so won't show up
    my $oldevent = $dbh->resultset('Event')->new({
        name => 'old event',
        synthetic_name => 'old event synthname',
        start_date => get_now->subtract(days => 14)->ymd('-'),
        start_time => '20:00',
    });
    $oldevent->insert;


    my $band1 = $dbh->resultset('Band')->new({
        name => 'test band 1',
    });
    $band1->insert;
    $band1->add_to_events($event1, {
        ordering => $i++,
         created_ts => '2022-07-31T13:33',
    });
    my $band2 = $dbh->resultset('Band')->new({
        name => 'test band 2',
    });
    $band2->insert;
    $band2->add_to_events($event1,
      {  ordering => $i++,
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
    my $muso2 = $dbh->resultset('Talent')->new({
        name => 'muso 2',
    });
    $muso2->insert;
    $muso2->add_to_bands($band1, {
         ordering => $i++,
         created_ts => '2022-07-31T13:33',
    });
    my $muso3 = $dbh->resultset('Talent')->new({
        name => 'muso 3',
    });
    $muso3->insert;
    # muso3 isn't in a band, they're just sitting in on event2
    $muso3->add_to_events($event1, {
         ordering => $i++,
         created_ts => '2022-07-31T13:33',
    });

    # muso4 is only attached to the old event, so they won't show up
    my $muso4 = $dbh->resultset('Talent')->new({
        name => 'muso 4',
    });
    $muso4->insert;
    $muso4->add_to_events($oldevent, {
         ordering => $i++,
         created_ts => '2022-04-01T13:33',
    });

    # we'll add some styles and stuff to the oldevent so we can test the JSON
    # rendering in livecalendar-results
    my $style1 = $dbh->resultset('Style')->new({
        name => 'ENGLISH',
    });
    $style1->insert;
    $style1->add_to_events($oldevent, {
        ordering => $i++,
        created_ts => '2022-04-01T13:33',
    });
    my $style2 = $dbh->resultset('Style')->new({
        name => 'CONTRA',
    });
    $style2->insert;
    $style2->add_to_events($oldevent, {
        ordering => $i++,
        created_ts => '2022-04-01T13:33',
    });

    my $caller1 = $dbh->resultset('Caller')->new({
        name => 'Alice Ackerby',
    });
    $caller1->insert;
    $caller1->add_to_events($oldevent, {
        ordering => $i++,
        created_ts => '2022-04-01T13:33',
    });
    my $caller2 = $dbh->resultset('Caller')->new({
        name => 'Bob Bronson',
    });
    $caller2->insert;
    $caller2->add_to_events($oldevent, {
        ordering => $i++,
        created_ts => '2022-04-01T13:33',
    });

    my $band3 = $dbh->resultset('Band')->new({
        name => 'Raging Rovers',
    });
    $band3->insert;
    $band3->add_to_events($oldevent, {
        ordering => $i++,
        created_ts => '2022-04-01T13:33',
    });
    my $band4 = $dbh->resultset('Band')->new({
        name => 'Blasting Berzerkers',
    });
    $band4->insert;
    $band4->add_to_events($oldevent, {
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
    $venue1->add_to_events($oldevent, {
        ordering => $i++,
        created_ts => '2022-04-01T13:33',
    });
    my $venue2 = $dbh->resultset('Venue')->new({
        vkey => 'bcv',
        hall_name => "Batman's Cave",
        address => '1 Wayne Manor',
        city => 'Gotham City',
    });
    $venue2->insert;
    $venue2->add_to_events($oldevent, {
        ordering => $i++,
        created_ts => '2022-04-01T13:33',
    });

    return {
        band1 => $band1->band_id,
        band2 => $band2->band_id,
        muso1 => $muso1->talent_id,
        muso2 => $muso2->talent_id,
        muso3 => $muso3->talent_id,
        # add more if needed
    }
}


# not a complete test
sub test_model_related_entities {

    my $data = bacds::Scheduler::Model::DanceFinder
        ->related_entities_for_upcoming_events();

    my @found_band_names;
    foreach my $band_id (sort keys %{$data->{bands}}) {
        my $band = $data->{bands}{$band_id};
        push @found_band_names, $band->name;
    }
    @found_band_names = sort @found_band_names;

    is_deeply \@found_band_names, ["test band 1", "test band 2"];


    my @found_muso_names;
    foreach my $muso_id (sort keys %{$data->{musos}}) {
        my $muso = $data->{musos}{$muso_id};
        push @found_muso_names, $muso->name;
    }
    @found_muso_names = sort @found_muso_names;

    is_deeply \@found_muso_names, ["muso 1", "muso 2", "muso 3"]
        or dump \@found_muso_names;
}

sub test_search_events {
    my ($fixture) = @_;


    my ($rs, @events, @musos, @bands);

    #
    # no args
    #
    $rs = bacds::Scheduler::Model::DanceFinder
        ->search_events();

    @events = $rs->all;

    is @events, 2, 'two events found with no args';

    is $events[0]->synthetic_name, 'test event 1 synthname';

    @musos = $events[0]->talent;
    is @musos, 1, 'one unattached muso for event 1';
    is $musos[0]->name, 'muso 3';
    @bands = $events[0]->bands;
    is @bands, 2, 'two bands for event 1';
    is $bands[0]->name, 'test band 1';
    is $bands[1]->name, 'test band 2';

    is $events[1]->synthetic_name, 'test event 2 synthname';


    #
    # search for band 1, muso 3 should just return event 1
    #
    $rs = bacds::Scheduler::Model::DanceFinder
        ->search_events(
            muso => [$fixture->{muso3}],
            band => [$fixture->{band1}],
        );

    @events = $rs->all;

    is @events, 1, 'one event found matching those args';

    is $events[0]->synthetic_name, 'test event 1 synthname';

    @musos = $events[0]->talent;
    is @musos, 1, 'one unattached muso for event 1';
    is $musos[0]->name, 'muso 3';
    @bands = $events[0]->bands;
    is @bands, 2, 'two bands for event 1';
    is $bands[0]->name, 'test band 1';
    is $bands[1]->name, 'test band 2';
    @musos = $bands[0]->talents;
    is $musos[0]->name, 'muso 1';
    is $musos[1]->name, 'muso 2';

}

sub test_dancefinder_results_endpoint {
    $Test->get_ok("/dancefinder-results", "GET /event/dancefinder ok");

    say $Test->content;

}

sub test_dancefinder_endpoint {
    $Test->get_ok("/dancefinder", "GET /event/dancefinder ok");

    like $Test->content, qr{
        (?-x:<select name="band" multiple>)\s+
        (?-x:<option value="">ALL BANDS</option>)\s+
        (?-x:<option value="1">test band 1</option>)\s+
        (?-x:<option value="2">test band 2</option>)\s+
             </select>
    }x, "bands found in form";

    like $Test->content, qr{
        (?-x:<select name="muso" multiple>)\s+
        (?-x:<option value="">ALL MUSICIANS</option>)\s+
        (?-x:<option value="1">muso 1</option>)\s+
        (?-x:<option value="2">muso 2</option>)\s+
        (?-x:<option value="3">muso 3</option>)\s+
             </select>
    }x, "musos found in form";
}

sub test_livecalendar_endpoint {
    my ($fixture) = @_;

    my $start = 1651112285; # 2022-04-27
    my $end = 1651112285 + 60*60*24*30;

    $Test->get_ok("/livecalendar-results?start=$start&end=$end", "GET /livecalendar-results ok");

    my ($data, $expected);

    $data = decode_json $Test->content;

    $expected = [
      {
        allDay => 1,
        backgroundColor => "white",
        borderColor => "white",
        end => "",
        id => 1,
        start => "2022-04-28",
        textColor => "white",
        title => " at . Music by test band 1, test band 2.",
        url => undef,
      },
      {
        allDay => 1,
        backgroundColor => "white",
        borderColor => "white",
        end => "",
        id => 2,
        start => "2022-04-28",
        textColor => "white",
        title => " at .",
        url => undef,
      },
    ];
    eq_or_diff $data, $expected, "livecalendar two default events ok";

    $start = get_now->subtract(days => 14)->epoch;
    $end = get_now->subtract(days => 1)->epoch;
    $Test->get_ok("/livecalendar-results?start=$start&end=$end", "GET /livecalendar-results ok");

    $data = decode_json $Test->content;

    $expected = [
      {
        allDay => 1,
        backgroundColor => "white",
        borderColor => "white",
        end => "",
        id => 3,
        start => "2022-04-14",
        textColor => "white",
        title => "ENGLISH/CONTRA at Mr. Hooper's Store in Sunny Day, and Batman's Cave in Gotham City. Led by Alice Ackerby and Bob Bronson. Music by Raging Rovers, Blasting Berzerkers.",
        url => undef,
      },
    ];
    eq_or_diff $data, $expected, "livecalendar two default events ok";

    #dump $data;
}
