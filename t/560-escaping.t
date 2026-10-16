# Checks that names and other plain-text fields are HTML-escaped on the public
# pages, without double-escaping the entities that are already in the data.

use 5.32.1;
use warnings;
use utf8;

use Data::Dump qw/dump/;
use Data::UUID;
use Test::More tests => 24;

use bacds::Scheduler::Util::Escape qw/escape_text/;
use bacds::Scheduler::Util::Test qw/setup_test_db get_tester/;
use bacds::Scheduler::Util::Time qw/get_now/;
use bacds::Scheduler::Util::Db qw/get_dbh/;

$ENV{TEST_NOW} = 1651112285; # 2022-04-27 19:18:05

test_escape_text();

setup_test_db;
my $Test = get_tester();
my $dbh = get_dbh();
my $fixture = setup_fixture();

test_page('/unearth');
test_page('/dancefinder-results?band=' . $fixture->{band}->band_id);
test_page('/serieslister?series_id=' . $fixture->{series}->series_id);
test_ldjson();

sub test_escape_text {
    is escape_text(undef), '', 'undef becomes empty string';
    is escape_text('Raven & Goose'), 'Raven &amp; Goose', 'bare & is escaped';
    is escape_text('Geoffrey&rsquo;s'), 'Geoffrey&rsquo;s', 'named entity left alone';
    is escape_text('Contra&#8212;lesson'), 'Contra&#8212;lesson', 'decimal entity left alone';
    is escape_text('&#x2014;'), '&#x2014;', 'hex entity left alone';
    is escape_text('AT&T rocks;'), 'AT&amp;T rocks;', 'a & that is not an entity is escaped';
    is escape_text(q{<script>alert("x's")</script>}),
        q{&lt;script&gt;alert(&quot;x's&quot;)&lt;/script&gt;},
        'markup and double quotes are escaped';
}

sub setup_fixture {
    my $format_date = sub {
        $dbh->storage->datetime_parser->format_datetime(shift->truncate(to => 'day'))
    };
    state $uuid_gen = Data::UUID->new;
    my $i = 1;

    my $bacds = $dbh->resultset('ParentOrg')->create({
        full_name => 'Bay Area Country Dance Society',
        abbreviation => 'BACDS',
    });
    my $series = $dbh->resultset('Series')->create({
        name => 'Escape <i>Series</i>',
        series_xid => 'ESCAPE-SERIES',
        series_url => 'https://bacds.org/series/contra/escape/',
        is_deleted => 0,
    });
    my $event = $dbh->resultset('Event')->create({
        name => 'Party<script>alert("event")</script>',
        synthetic_name => 'escape test event',
        short_desc => 'a dance',
        start_date => $format_date->(get_now),
        start_time => '20:00:00',
        series_id => $series->series_id,
        uuid => $uuid_gen->to_string($uuid_gen->create),
    });
    $event->add_to_parent_orgs($bacds, { ordering => $i++ });

    my $special = $dbh->resultset('Style')->create({ name => 'SPECIAL' });
    $special->add_to_events($event, { ordering => $i++ });

    my $band = $dbh->resultset('Band')->create({
        name => 'Raven & Goose<script>alert("band")</script>',
    });
    $band->add_to_events($event, { ordering => $i++ });

    my $caller = $dbh->resultset('Caller')->create({
        name => 'Cal<img src=x onerror=alert("caller")>',
    });
    $caller->add_to_events($event, { ordering => $i++ });

    my $venue = $dbh->resultset('Venue')->create({
        vkey => 'GIC',
        hall_name => 'Geoffrey&rsquo;s Inner Circle',
        address => '410 14th St.',
        city => 'Oakland<script>alert("city")</script>',
    });
    $venue->add_to_events($event, { ordering => $i++ });

    return { series => $series, event => $event, band => $band };
}

sub test_page {
    my ($url) = @_;

    $Test->get_ok($url, "GET $url");
    my $content = $Test->content;

    unlike $content, qr{<script>alert|<img src=x}, "$url: no raw markup from the data"
        or diag_context($content, qr{alert});
    like $content, qr{Raven &amp; Goose&lt;script&gt;}, "$url: band name escaped"
        or diag_context($content, qr{Raven});
    like $content, qr{Geoffrey&rsquo;s Inner Circle}, "$url: entity in venue name kept"
        or diag_context($content, qr{Geoffrey});
    unlike $content, qr{&amp;rsquo;}, "$url: entity not double-escaped";
}

sub test_ldjson {
    my $url = '/serieslister?event_id=' . $fixture->{event}->event_id;
    $Test->get_ok($url, "GET $url");
    my $content = $Test->content;
    my ($ldjson) = $content =~ m{<script type="application/ld\+json">(.+?)</script>}s
        or return fail 'found the ld+json script';
    like $ldjson, qr{Raven & Goose<script>alert\(\\"band\\"\)<\\/script>},
        'band name is in the ld+json with "</" escaped as "<\/"';
}

sub diag_context {
    my ($content, $re) = @_;
    while ($content =~ m{(.{0,80}$re.{0,80})}g) {
        diag $1;
    }
}
