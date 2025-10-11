
use 5.16.0;
use warnings;

# this tests dancefinder and livecalendar and serieslister, both the backend
# and the url endpoints

use Data::Dump qw/dump/;
use JSON::MaybeXS qw/decode_json/;
use Test::Differences qw/eq_or_diff/;
use Test::More tests => 69;

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
test_model_related_entities();
test_dancefinder_form_endpoint();
test_dancefinder_results_endpoint($fixture);
test_search_events($fixture);
test_livecalendar_endpoint($fixture);
test_serieslister($fixture);
test_serieslister_endpoint($fixture);
test_serieslister_single_event_endpoint($fixture);
test_serieslister_ldjson($fixture);
test_calendar_get_events();
test_calendar_get_venues();
test_new_calendar();

sub setup_fixture {

    my $bacds_parent_org = $dbh->resultset('ParentOrg')->new({
        full_name => 'Bay Area Country Dance Society',
        abbreviation => 'BACDS',
    });
    $bacds_parent_org->insert;

    my $nbcds_parent_org = $dbh->resultset('ParentOrg')->new({
        full_name => 'North Bay',
        abbreviation => 'NBCDS',
    });
    $nbcds_parent_org->insert;

    my $event1 = $dbh->resultset('Event')->new({
        name => 'test event 1',
        synthetic_name => 'test event 1 synthname',
        custom_url => 'http://custom-url/test-event-1',
        short_desc => 'big <b> dance party &#9786',
        start_date => get_now->ymd('-'),
        start_time => '20:00:00',
    });
    $event1->insert;
    $event1->add_to_parent_orgs($bacds_parent_org, { ordering => 1 });

    my $event2 = $dbh->resultset('Event')->new({
        synthetic_name => 'test event 2 synthname',
        start_date => get_now->ymd('-'),
        start_time => '20:00:00',
    });
    $event2->insert;
    $event2->add_to_parent_orgs($bacds_parent_org, { ordering => 1 });

    # this one is before today so won't show up
    my $oldevent = $dbh->resultset('Event')->new({
        name => 'Ye Oldde Ewent',
        synthetic_name => 'old event synthname',
        start_date => get_now->subtract(days => 14)->ymd('-'),
        start_time => '20:00:00',
    });
    $oldevent->insert;
    $oldevent->add_to_parent_orgs($nbcds_parent_org, { ordering => 1 });

    # is_deleted shouldn't show up
    my $deleted_event = $dbh->resultset('Event')->new({
        name => 'deleted event',
        synthetic_name => 'deleted event synthname',
        short_desc => 'deleted <b> dance party &#9785;',
        is_deleted => 1,
        start_date => get_now->ymd('-'),
        start_time => '20:00:00',
    });
    $deleted_event->insert;

    my $multidayevent = $dbh->resultset('Event')->new({
        name => 'test multiday event 1',
        synthetic_name => 'test multiday event 1 synthname',
        short_desc => 'multiday event',
        start_date => get_now->ymd('-'),
        start_time => '20:00:00',
        end_date => get_now->add(days=>1)->ymd('-'),
        end_time => '00:15:00',
    });
    $multidayevent->insert;
    $multidayevent->add_to_parent_orgs($bacds_parent_org, { ordering => 1 });

    my $band1 = $dbh->resultset('Band')->new({
        name => 'test band 1',
    });
    $band1->insert;
    $band1->add_to_events($event1, {
        ordering => $i++,
         created_ts => '2022-07-31T13:33:00',
    });
    my $band2 = $dbh->resultset('Band')->new({
        name => 'test band 2',
    });
    $band2->insert;
    $band2->add_to_events($event1,
      {  ordering => $i++,
         created_ts => '2022-07-31T13:33:00',
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
         created_ts => '2022-07-31T13:33:00',
    });
    my $muso2 = $dbh->resultset('Talent')->new({
        name => 'muso 2',
    });
    $muso2->insert;
    $muso2->add_to_bands($band1, {
         ordering => $i++,
         created_ts => '2022-07-31T13:33:00',
    });
    my $muso3 = $dbh->resultset('Talent')->new({
        name => 'muso 3',
    });
    $muso3->insert;
    # muso3 isn't in a band, they're just sitting in on event1
    $muso3->add_to_events($event1, {
         ordering => $i++,
         created_ts => '2022-07-31T13:33:00',
    });

    # muso4 is only attached to the old event, so they won't show up
    my $muso4 = $dbh->resultset('Talent')->new({
        name => 'muso 4',
    });
    $muso4->insert;
    $muso4->add_to_events($oldevent, {
         ordering => $i++,
         created_ts => '2022-04-01T13:33:00',
    });

    # deletedmuso is in a band but is_deleted, so shouldn't show up
    my $deleted_muso = $dbh->resultset('Talent')->new({
        name => 'deleted muso',
        is_deleted => 1,
    });
    $deleted_muso->insert;
    $deleted_muso->add_to_bands($band1, {
         ordering => $i++,
         created_ts => '2022-07-31T13:33:00',
    });


    # we'll add some styles and stuff to the oldevent so we can test the JSON
    # rendering in livecalendar-results
    my $style1 = $dbh->resultset('Style')->new({
        name => 'ENGLISH',
    });
    $style1->insert;
    $style1->add_to_events($oldevent, {
        ordering => $i++,
        created_ts => '2022-04-01T13:33:00',
    });
    my $style2 = $dbh->resultset('Style')->new({
        name => 'CONTRA',
    });
    $style2->insert;
    $style2->add_to_events($oldevent, {
        ordering => $i++,
        created_ts => '2022-04-01T13:33:00',
    });
    $style2->add_to_events($event2, {
        ordering => $i++,
        created_ts => '2022-04-01T13:33:00',
    });

    my $caller1 = $dbh->resultset('Caller')->new({
        name => 'Alice Ackerby',
    });
    $caller1->insert;
    $caller1->add_to_events($oldevent, {
        ordering => $i++,
        created_ts => '2022-04-01T13:33:00',
    });
    my $caller2 = $dbh->resultset('Caller')->new({
        name => 'Bob Bronson',
    });
    $caller2->insert;
    $caller2->add_to_events($oldevent, {
        ordering => $i++,
        created_ts => '2022-04-01T13:33:00',
    });

    my $band3 = $dbh->resultset('Band')->new({
        name => 'Raging Rovers',
    });
    $band3->insert;
    $band3->add_to_events($oldevent, {
        ordering => $i++,
        created_ts => '2022-04-01T13:33:00',
    });
    my $band4 = $dbh->resultset('Band')->new({
        name => 'Blasting Berzerkers',
    });
    $band4->insert;
    $band4->add_to_events($oldevent, {
        ordering => $i++,
        created_ts => '2022-04-01T13:33:00',
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
        created_ts => '2022-04-01T13:33:00',
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
        created_ts => '2022-04-01T13:33:00',
    });

    my $series1 = $dbh->resultset('Series')->new({
        name => "The Dance-A-Week Series",
        series_xid => 'DAW',
        series_url => "https://bacds.org/dance-a-week/",
    });
    $series1->insert;

    foreach my $event ($oldevent, $event1, $multidayevent, $event2, $deleted_event) {
        $event->series_id($series1->series_id);
        $event->update;
    }

    return {
        event1 => $event1->event_id,
        multiday=> $multidayevent->event_id,
        event2 => $event2->event_id,
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
        series1 => $series1->series_id,
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

    is @events, 3, 'three events found with no args';

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
        (?-x:<select name="band"[^>]*>)\s+
        (?-x:<option value="">ALL BANDS</option>)\s+
        (?-x:<option value="1">\s+test band 1\s+</option>)\s+
        (?-x:<option value="2">\s+test band 2\s+</option>)\s+
             </select>
    }x, "bands found in form";
#

    like $Test->content, qr{
        (?-x:<select name="muso"[^>]*>)\s+
        (?-x:<option value="">ALL MUSICIANS</option>)\s+
        (?-x:<option value="1">\s+muso 1\s+</option>)\s+
        (?-x:<option value="2">\s+muso 2\s+</option>)\s+
        (?-x:<option value="3">\s+muso 3\s+</option>)\s+
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
        Thursday,.April.28.&\#8226;.<span.class="event-time-range">8:00pm</span>:\s+
        <strong>\s*</strong>\s+at\s+
        <a.href="http://custom-url/test-event-1">Mr\..Hooper's.Store.in.Sunny.Day</a>\.\s+
            Music.by \s+
            test.band.1,.test.band.2:.muso.3 \s+
        <span.class="special-event-name">\s*test.event.1\s*</span>
    }x, "event1's title looks right";

    like $body, qr{
        Thursday,.April.28.&\#8226;.<span.class="event-time-range">8:00pm</span>:\s+
        <strong>\s*CONTRA\s*</strong>\s+at\s+
        <a.href="https://bacds.org/dance-a-week/">Mr\..Hooper's.Store.in.Sunny.Day</a>\. \s+
        <a.href="https://bacds.org/dance-a-week/">More.Info</a> \s+
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

    #
    # new param: style-name=CONTRA
    #
    $q = 'style-name=ENGLISH&style-name=CONTRA';

    $Test->get_ok("/dancefinder-results?$q", "GET /dancefinder-results?$q ok");

    ($body) = $Test->content =~ m{(<body.+?>.+</body>)}ms;

    like $body, qr{
        <div.class="search_args"> \s+
            <span.class="search_arg">English</span> \s+ or \s+
            <span.class="search_arg">Contra</span> \s+
            Dances \s+
        </div>
    }x, 'query with style-name arg looks ok';
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
        backgroundColor => "yellow",
        borderColor => "antiquewhite",
        id => 1,
        eventColor => 'yellow',
        start => "2022-04-28T20:00:00",
        textColor => "black",
        title => " test event 1 at Mr. Hooper's Store in Sunny Day. Music by test band 1, test band 2: muso 3. Big  dance party \x{263a}",
        url => 'http://custom-url/test-event-1',
      },
      {
        backgroundColor => "coral",
        borderColor => "bisque",
        eventColor => 'coral',
        id => 2,
        start => "2022-04-28T20:00:00",
        textColor => "black",
        title => "CONTRA  at Mr. Hooper\'s Store in Sunny Day.",
        url => 'https://bacds.org/dance-a-week/',
      },
      {
        allDay => 1, 
        backgroundColor => "yellow",
        borderColor => "antiquewhite",
        end => '2022-04-30T00:15:00', 
        eventColor => 'yellow',
        id => 5,
        start => "2022-04-28T20:00:00",
        textColor => "black",
        title => " test multiday event 1. Multiday event",
        url => 'https://bacds.org/dance-a-week/',
      },
    ];
    eq_or_diff $data, $expected, "livecalendar three default events json";

    $start = get_now->subtract(days => 14)->epoch;
    $end = get_now->subtract(days => 1)->epoch;
    $Test->get_ok("/livecalendar-results?start=$start&end=$end", "GET /livecalendar-results ok");

    $data = decode_json $Test->content;

    $expected = [
      {
        backgroundColor => "beige",
        borderColor => "dimgrey",
        eventColor => 'beige',
        id => 3,
        start => "2022-04-14T20:00:00",
        textColor => "darkgrey",
        title =>
            "ENGLISH/CONTRA ".
            "Ye Oldde Ewent ".
            "at Mr. Hooper's Store in Sunny Day, and Batman's Cave in Gotham City. ".
            "Led by Alice Ackerby and Bob Bronson. ".
            "Music by Raging Rovers, Blasting Berzerkers: muso 4. (NBCDS)",
        url => 'https://bacds.org/dance-a-week/',
      },
    ];
    eq_or_diff $data, $expected, "livecalendar old event json";

    #dump $data;
}

sub test_serieslister {
    my ($fixture) = @_;

    my $c = 'bacds::Scheduler::Model::SeriesLister';

    my ($data, $series);

    #
    # look up by series_id
    #
    $data = $c->get_upcoming_events_for_series(series_id => $fixture->{series1});

    $series = $data->{series};
    is $series->name, 'The Dance-A-Week Series';
    is $series->series_xid, 'DAW';
    is scalar  @{ $data->{events} }, 3, "two events coming up in this series by id";
    is $data->{events}[0]->synthetic_name, 'test event 1 synthname';
    is $data->{events}[1]->synthetic_name, 'test event 2 synthname';

    #
    # look up by event path
    #
    $data = $c->get_upcoming_events_for_series(series_xid => 'DAW');

    $series = $data->{series};
    is $series->name, 'The Dance-A-Week Series';
    is scalar  @{ $data->{events} }, 3, "three events coming up in this series by path";
    is $data->{events}[0]->synthetic_name, 'test event 1 synthname';
    is $data->{events}[1]->synthetic_name, 'test event 2 synthname';
}

sub test_serieslister_endpoint {
    my ($fixture) = @_;

    #
    # test with series_id
    #
    my $series_id = $fixture->{series1};
    $Test->get_ok("/serieslister?series_id=$series_id", "GET /serieslister?series_id ok");

    like $Test->content, qr{
        <article.class=".+?"> \s+
            <p.class=".+?"> \s+
                <b(?:.class=".+?")?> \s+
                <a.(?:class=".+?".)?href="http://localhost/serieslister\?event_id=2"> \s+
                Thursday,.April.28 \s+
                </a> \s+
                </b> \s+
            </p> \s+
            <p.class=".+?"> \s*
                    Mr..Hooper's.Store,.123.Sesame.St.,.Sunny.Day. \s*
            </p> \s+
            <p.class=".+?">8:00pm \s+
            </p> \s+
        </article>
    }msx, 'serieslist id output ok';

    #
    # test with the XID
    #
    $Test->get_ok("/serieslister?series_xid=DAW", "GET /serieslister?series_xid");

    like $Test->content, qr{
        <article.class=".+?"> \s+
            <p.class=".+?"> \s+
                <b(?:.class=".+?")?> \s+
                <a.(?:class=".+?".)?href="http://localhost/serieslister\?event_id=2"> \s+
                Thursday,.April.28 \s+
                </a> \s+
                </b> \s+
            </p> \s+
            <p.class=".+?"> \s*
                    Mr..Hooper's.Store,.123.Sesame.St.,.Sunny.Day. \s*
            </p> \s+
            <p.class=".+?">8:00pm \s+
            </p> \s+
        </article>
    }x, 'serieslist xid output ok';
}

sub test_serieslister_single_event_endpoint {
    my ($fixture) = @_;

    my $tester = get_tester(
        debug => 0,
        env => {
            QUERY_STRING_UNESCAPED => "event_id=$fixture->{event1}",
            REQUEST_URI => "/series/english/berkeley_wed?event_id=$fixture->{event1}",
        },
    );

    # if this works without a series_xid parameter, then we're
    # exercising the code paths for single events
    $tester->get_ok("/serieslister", 'GET /serieslister w/ SSI event_id param');

    # this is the same href as the above test
    like $tester->content,
         qr{<a (?:class=".+" )?href="http://localhost/series/english/berkeley_wed\?event_id=1">},
         'single event request worked, href is correct';

    like $tester->content, qr{\Q<script type="application/ld+json">},
        'ld+json was included in single event listing';
        # (contents of ld+json are tested in test_serieslister_ldjson)

}
sub test_serieslister_ldjson {
    my ($fixture) = @_;

    my $event_id = $fixture->{event1};

    my $event = $dbh->resultset('Event')->find({
        event_id => $event_id,
    });

    my $mock_request = Dancer2::Core::Request->new(env => {
        REQUEST_METHOD => 'GET',
        SCRIPT_NAME => '/dancefinder/serieslister',
        PATH_INFO => '',
        REQUEST_URI => "/dancefinder/serieslister?event_id=$event_id",
        QUERY_STRING => "event_id=$event_id",
        SERVER_NAME => 'www.bacds.org',
        SERVER_PORT => '80',
        SERVER_PROTOCOL => 'HTTP/1.1',
        CONTENT_LENGTH => 0,
        CONTENT_TYPE => 'text/html',
        'psgi.version' => [1,1],
        'psgi.url_scheme' => 'http',
    });
    no warnings 'redefine';
    local *bacds::Scheduler::request = sub { $mock_request };
    my $json = bacds::Scheduler::Model::SeriesLister->generate_ldjson($event);

    # is is a bretty blunt test. so shoot me
    eq_or_diff $json, <<'EOL', 'ldjson generated ok';
    <script type="application/ld+json">
    {
   "@context" : "http://schema.org",
   "@type" : [
      "Event",
      "DanceEvent"
   ],
   "description" : " Dancing at Mr. Hooper's Store in Sunny Day. Everyone welcome, beginners and experts! No partner necessary. big <b> dance party &#9786 (Prices may vary for special events or workshops. Check the calendar or website for specifics.)",
   "endDate" : "2022-04-28T00:00:00",
   "eventAttendanceMode" : "https://schema.org/OfflineEventAttendanceMode",
   "eventStatus" : "https://schema.org/EventScheduled",
   "image" : "https://www.bacds.org/graphics/bacdsweblogomed.gif",
   "location" : {
      "@context" : "http://schema.org",
      "@type" : "Place",
      "address" : {
         "@type" : "PostalAddress",
         "addressCountry" : "USA",
         "addressLocality" : "Sunny Day",
         "addressRegion" : "California",
         "postalCode" : null,
         "streetAddress" : "123 Sesame St."
      },
      "name" : "Mr. Hooper's Store"
   },
   "name" : " Dancing, calling by  to the music of test band 1, test band 2",
   "offers" : [
      {
         "@type" : "Offer",
         "availability" : "http://schema.org/LimitedAvailability",
         "name" : "supporters",
         "price" : "25.00",
         "priceCurrency" : "USD",
         "url" : "http://www.bacds.org/dancefinder/serieslister?event_id=1",
         "validFrom" : "2022-04-28"
      },
      {
         "@type" : "Offer",
         "availability" : "http://schema.org/LimitedAvailability",
         "name" : "non-members",
         "price" : "20.00",
         "priceCurrency" : "USD",
         "url" : "http://www.bacds.org/dancefinder/serieslister?event_id=1",
         "validFrom" : "2022-04-28"
      },
      {
         "@type" : "Offer",
         "availability" : "http://schema.org/LimitedAvailability",
         "name" : "members",
         "price" : "15.00",
         "priceCurrency" : "USD",
         "url" : "http://www.bacds.org/dancefinder/serieslister?event_id=1",
         "validFrom" : "2022-04-28"
      },
      {
         "@type" : "Offer",
         "availability" : "http://schema.org/LimitedAvailability",
         "name" : "students or low-income or pay what you can",
         "price" : "6.00",
         "priceCurrency" : "USD",
         "url" : "http://www.bacds.org/dancefinder/serieslister?event_id=1",
         "validFrom" : "2022-04-28"
      }
   ],
   "organizer" : {
      "@context" : "http://schema.org",
      "@type" : "Organization",
      "name" : "Bay Area Country Dance Society",
      "url" : "https://www.bacds.org/"
   },
   "performer" : [
      {
         "@type" : "MusicGroup",
         "name" : "test band 1, test band 2"
      },
      {
         "@type" : "Person",
         "name" : ""
      }
   ],
   "startDate" : "2022-04-28T20:00:00"
}

    </script>
EOL
}

sub test_calendar_get_events {

    my @events = bacds::Scheduler::Model::Calendar->load_events_for_month('2022', '04');

    is scalar @events, 4, 'calendar gets all four undeleted events';
    is $events[0]->band, 'Raging Rovers, Blasting Berzerkers';
    is $events[0]->leader, 'Alice Ackerby, Bob Bronson';
    is $events[0]->type, 'ENGLISH/CONTRA';
    is $events[0]->loc, 'hop/bcv';
    is $events[0]->startday, '2022-04-14';
    is $events[1]->startday, '2022-04-28';
    is $events[2]->startday, '2022-04-28';
    is $events[2]->startday_obj->ymd, '2022-04-28';
}

sub test_calendar_get_venues {

    my @venues = bacds::Scheduler::Model::Calendar->load_venue_list_for_month('2022', '04');

    is @venues, 1, 'just one venue';
    is $venues[0], q{hop|Mr. Hooper's Store|123 Sesame St.|Sunny Day};

}

# The dance-scheduler is now handling /calendars/2023/ and onward.
# We'll test it with the dates/events we've got.
sub test_new_calendar {
    my $series_id = $fixture->{series1};
    $Test->get_ok("/calendars/2022/04/", "GET /calendars/2022/04/ ok");
    like $Test->content, qr{<td class="calendar">    <a href="#2022-04-14">  14  </a>   </td>},
         'calendar part has a date linked';
    like $Test->content, qr{<td class="callisting">Mr. Hooper's Store</td>},
        'venue part has Mr. Hooper';

    like $Test->content, qr{
            <td.class="callisting"> \s+
                <a.name="2022-04-28">April&nbsp;28 \s+
                </a> \s+
            </td> \s+
            <td.class="callisting"> \s+
                    <span.class="special-event-name">test.event.1</span>.\(\) \s+
            </td>
    }x, 'listings part has a listing';

    # and in a continuation of the trailing slash drama, it turns out the app
    # needs to handle both--we can't just rely on /calendars/.htaccess because
    # e.g.'https://bacds.org/dance-scheduler/calendars/2034/06' doesn't go
    # through that filesystem directory, but goes straight to the
    # dance-scheduler app, so make sure it's working
    $Test->get_ok("/calendars/2022/04", "GET /calendars/2022/04/ ok");
}
