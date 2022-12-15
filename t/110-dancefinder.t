
use 5.16.0;
use warnings;

# this tests dancefinder and livecalendar and series-lister, both the backend
# and the url endpoints

use Data::Dump qw/dump/;
use JSON::MaybeXS qw/decode_json/;
use Test::Differences qw/eq_or_diff/;
use Test::More tests => 36;

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
test_dancefinder_form_endpoint();
test_dancefinder_results_endpoint($fixture);
test_search_events($fixture);
test_livecalendar_endpoint($fixture);
test_series_lister($fixture);
test_series_lister_endpoint($fixture);

sub setup_fixture {

    my $event1 = $dbh->resultset('Event')->new({
        name => 'test event 1',
        synthetic_name => 'test event 1 synthname',
        custom_url => 'http://custom-url/test-event-1',
        short_desc => 'big <b> dance party &#9786',
        start_date => get_now->ymd('-'),
        start_time => '20:00',
    });
    $event1->insert;
    my $event2 = $dbh->resultset('Event')->new({
        synthetic_name => 'test event 2 synthname',
        start_date => get_now->ymd('-'),
        start_time => '20:00',
    });
    $event2->insert;

    # this one is before today so won't show up
    my $oldevent = $dbh->resultset('Event')->new({
        name => 'Ye Oldde Ewent',
        synthetic_name => 'old event synthname',
        start_date => get_now->subtract(days => 14)->ymd('-'),
        start_time => '20:00',
    });
    $oldevent->insert;

    # is_deleted shouldn't show up
    my $deleted_event = $dbh->resultset('Event')->new({
        name => 'deleted event',
        synthetic_name => 'deleted event synthname',
        short_desc => 'old <b> dance party &#9785;',
        is_deleted => 1,
        start_date => get_now->ymd('-'),
        start_time => '20:00',
    });
    $deleted_event->insert;

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
    # muso3 isn't in a band, they're just sitting in on event1
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

    # deletedmuso is in a band but is_deleted, so shouldn't show up
    my $deleted_muso = $dbh->resultset('Talent')->new({
        name => 'deleted muso',
        is_deleted => 1,
    });
    $deleted_muso->insert;
    $deleted_muso->add_to_bands($band1, {
         ordering => $i++,
         created_ts => '2022-07-31T13:33',
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
    $style2->add_to_events($event2, {
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
    $venue1->add_to_events($_, {
        ordering => $i++,
        created_ts => '2022-04-01T13:33',
    }) for ($oldevent, $event1, $event2);

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

    my $series1 = $dbh->resultset('Series')->new({
        name => "The Dance-A-Week Series",
        series_url => "https://series-url/dance-a-week",
    });
    $series1->insert;
    $event2->series_id($series1->series_id);
    $event2->update;

    return {
        band1 => $band1->band_id,
        band2 => $band2->band_id,
        caller1 => $caller1->caller_id,
        caller2 => $caller2->caller_id,
        muso1 => $muso1->talent_id,
        muso2 => $muso2->talent_id,
        muso3 => $muso3->talent_id,
        style1 => $style1->style_id,
        style2 => $style2->style_id,
        venue1 => $venue1->venue_id,
        venue2 => $venue2->venue_id,
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

sub test_dancefinder_form_endpoint {
    $Test->get_ok("/dancefinder", "GET /dancefinder ok");

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

sub test_dancefinder_results_endpoint {
    my ($fixture) = @_;

    #
    # request with no params
    #
    $Test->get_ok("/dancefinder-results", "GET /dancefinder-results ok");

    my ($body, $q);

    ($body) = $Test->content =~ m{(<body.+?>.+</body>)}ms;

    like $body, qr{<div class="search_args">\s+Dances\s+</div>},
        'vanilla results header with no params';

    like $body, qr{
        Thursday,.28.April,.2022:.<strong></strong>.at \s+
        <a.href="http://custom-url/test-event-1">Mr..Hooper's.Store.in.Sunny.Day</a>. \s+
            Music.by \s+
            test.band.1,.test.band.2:.muso.3 \s+
        <em>test.event.1</em>
    }x, "event1's title looks right";

    like $body, qr{
        Thursday,.28.April,.2022:.<strong>CONTRA</strong>.at. \s+
        <a.href="https://series-url/dance-a-week">Mr..Hooper's.Store.in.Sunny.Day</a>. \s+
        </p>
    }x, "event2's title looks right, no event.name, no band, caller or talent";


    #
    # with more params
    #
    $q = join '&',
        "caller=$fixture->{caller1}",
        "venue=$fixture->{venue1}",
        "style=$fixture->{style1}",
        "band=$fixture->{band1}",
    ;

    $Test->get_ok("/dancefinder-results?$q", "GET /dancefinder-results?$q ok");

    ($body) = $Test->content =~ m{(<body.+?>.+</body>)}ms;

    like $body, qr{
        <div.class="search_args"> \s+
            <span.class="search_arg">English</span> \s+
            Dances \s+
            At.<span.class="search_arg">Mr..Hooper's.Store.in.Sunny.Day</span> \s+
            Led.By.<span.class="search_arg">Alice.Ackerby</span> \s+
            Featuring \s+
            <span.class="search_arg">test.band.1</span> \s+
        </div>
    }x, 'query with bunch of args looks ok';

    #
    # whole buncha params
    #
    $q = join '&',
        "caller=$fixture->{caller1}",
        "caller=$fixture->{caller2}",
        "venue=$fixture->{venue1}",
        "venue=$fixture->{venue2}",
        "style=$fixture->{style1}",
        "style=$fixture->{style2}",
        "band=$fixture->{band1}",
        "band=$fixture->{band2}",
    ;

    $Test->get_ok("/dancefinder-results?$q", "GET /dancefinder-results?$q ok");

    ($body) = $Test->content =~ m{(<body.+?>.+</body>)}ms;

    like $body, qr{
        <div.class="search_args"> \s+
            <span.class="search_arg">English</span>.or. \s+
            <span.class="search_arg">Contra</span> \s+
            Dances \s+
            At.<span.class="search_arg">Mr..Hooper's.Store.in.Sunny.Day</span>.or. \s+
            <span.class="search_arg">Batman's.Cave.in.Gotham.City</span> \s+

            Led.By.<span.class="search_arg">Alice.Ackerby</span>.or \s+
            <span.class="search_arg">Bob.Bronson</span> \s+

            Featuring \s+
            <span.class="search_arg">test.band.1</span>, \s+
            and \s+
            <span.class="search_arg">test.band.2</span> \s+
        </div>
    }x, 'query with bunch of args looks ok';
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
        backgroundColor => "yellow",
        borderColor => "antiquewhite",
        end => "",
        id => 1,
        start => "2022-04-28",
        textColor => "black",
        title => " test event 1 at Mr. Hooper\'s Store in Sunny Day. Music by test band 1, test band 2. - big  dance party \x{263a}",
        url => 'http://custom-url/test-event-1',
      },
      {
        allDay => 1,
        backgroundColor => "coral",
        borderColor => "bisque",
        end => "",
        id => 2,
        start => "2022-04-28",
        textColor => "black",
        title => "CONTRA  at Mr. Hooper\'s Store in Sunny Day.",
        url => 'https://series-url/dance-a-week',
      },
    ];
    eq_or_diff $data, $expected, "livecalendar two default events json";

    $start = get_now->subtract(days => 14)->epoch;
    $end = get_now->subtract(days => 1)->epoch;
    $Test->get_ok("/livecalendar-results?start=$start&end=$end", "GET /livecalendar-results ok");

    $data = decode_json $Test->content;

    $expected = [
      {
        allDay => 1,
        backgroundColor => "darkturquoise",
        borderColor => "darkblue",
        end => "",
        id => 3,
        start => "2022-04-14",
        textColor => "black",
        title =>
            "ENGLISH/CONTRA ".
            "Ye Oldde Ewent ".
            "at Mr. Hooper's Store in Sunny Day, and Batman's Cave in Gotham City. ".
            "Led by Alice Ackerby and Bob Bronson. ".
            "Music by Raging Rovers, Blasting Berzerkers.",
        url => undef,
      },
    ];
    eq_or_diff $data, $expected, "livecalendar old event json";

    #dump $data;
}

sub test_series_lister {
    my ($fixture) = @_;

    # will there be any logic not in the endpoint?
}

sub test_series_lister_endpoint {
    $Test->get_ok("/series-lister", "GET /series-lister ok");

    is $Test->content, 'this is your stub series-lister', 'series-lister content ok';
}
