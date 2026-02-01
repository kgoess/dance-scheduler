
use 5.31.0;
use feature 'signatures';
use warnings;
no warnings 'experimental::signatures';
use utf8;

use Data::Dump qw/dump/;
use JSON::MaybeXS qw/decode_json/;
use Test::More tests => 14;
use Plack::Test;
use Test::Differences qw/eq_or_diff/;

use bacds::Scheduler::ICal;
use bacds::Scheduler::Util::Test qw/setup_test_db get_tester/;
use bacds::Scheduler::Util::Time qw/get_now/;
use bacds::Scheduler::Util::Db qw/get_dbh/;

my $hex = qr{[0-9A-F]};
my $UUID_RE = qr/$hex{8}-$hex{4}-$hex{4}-$hex{4}-$hex{12}/;

setup_test_db;
my $test = get_tester(auth => 1);
my $dbh = get_dbh();
$ENV{TEST_NOW} = 1651112285;
my $decoded;

# series
my $series_1 = {
    name       => 'Bree Mersday English',
    series_xid => 'BREE-MERS-ENG',
    frequency  => 'third Mersday',
    series_url => 'https://bacds.org/bree-mersday-eng',
};
$test->post_ok('/series/', $series_1);
$decoded = decode_json($test->content);
my $series_1_id = $decoded->{data}{series_id};
my $series_2 = {
    name       => 'Bywater Trewsday Contra',
    series_xid => 'BYWATER-TREW-CONTRA',
    frequency  => 'fourth Trewsday',
    series_url => 'https://bacds.org/bywater-trewsday-contra',
};
$test->post_ok('/series/', $series_2);
$decoded = decode_json($test->content);
my $series_2_id = $decoded->{data}{series_id};

# styles
my $style_1 = {
    name       => 'pipesmoking',
    frequency  => 'fourth Trewsday',
};
$test->post_ok('/style/', $style_1 );
$decoded = decode_json($test->content);
my $style_1_id = $decoded->{data}{style_id};
my $style_2 = {
    name       => 'maypole',
    frequency  => 'may morning',
};
$test->post_ok('/style/', $style_2 );
$decoded = decode_json($test->content);
my $style_2_id = $decoded->{data}{style_id};

# venues
my $venue = {
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
$test->post_ok('/venue/', $venue );
$decoded = decode_json($test->content);
my $venue_id = $decoded->{data}{venue_id};

# callers
my $caller = {
    name => 'Rose Gamgee',
};
$test->post_ok('/caller/', $caller );
$decoded = decode_json($test->content);
my $caller_id = $decoded->{data}{caller_id};

# parent_orgs
my $parent_org = {
    full_name    => 'Bree Ambidextrous Cloth Dying',
    abbreviation => 'BACDS',
    
};
$test->post_ok('/parent_org/', $parent_org );
ok($test->success, 'created parent_org');
$decoded = decode_json($test->content);
my $parent_org_id = $decoded->{data}{parent_org_id};


my $event_1 = {
    start_date => "2022-05-01",
    start_time => "20:00",

    end_date => "2022-05-01",
    end_time => "22:00",

    short_desc  => "itsa shortdesc 1 無為",
    is_canceled => 0,
    and_friends => 0,
    is_series_defaults => 0,
    synthetic_name => "ENGLISH this is first event",
    series_id   => $series_1_id,
    style_id => [$style_1_id, $style_2_id],
    venue_id => $venue_id,
    caller_id => $caller_id,
    parent_org_id => $parent_org_id,
};
my $event_2 = {
    start_date => "2022-05-02",
    start_time => "20:00",

    short_desc  => "new\nlines\nshortdesc",
    is_canceled => 0,
    and_friends => 0,
    is_series_defaults => 0,
    synthetic_name  => "CONTRA this is second event ﷽",
    series_id   => $series_2_id,
    parent_org_id => $parent_org_id,
};
$test->post_ok('/event/', $event_1 );
$test->post_ok('/event/', $event_2 );

basic_test();
test_url_endpoint($test);

sub basic_test {

    my $rs = bacds::Scheduler::Model::DanceFinder
        ->search_events();

    my @events = $rs->all;

    my $vevent = bacds::Scheduler::ICal->event_to_ical($events[0], 'gopher', 'minnesota.edu');

    my $calendar = Data::ICal->new(
        calname => 'BACDS Calendar',
        rfc_strict => 1,
    );
    $calendar->add_entry($vevent);

    my $got = $calendar->as_string;
    $got =~ s/UID:$UUID_RE/UID:someuuid/;

    my $expected_1 = <<'EOL';
BEGIN:VCALENDAR
VERSION:2.0
PRODID:Data::ICal 0.24
X-WR-CALNAME:BACDS Calendar
BEGIN:VEVENT
CATEGORIES:pipesmoking
CATEGORIES:maypole
CLASS:PUBLIC
CREATED:20220428T021805
DESCRIPTION:Rose Gamgee itsa shortdesc 1 無為
DTEND:20220501T220000
DTSTAMP:20220428T021805
DTSTART:20220501T200000
LAST-MODIFIED:20220428T021805
LOCATION:the hall\, 123 Sesame St.\, Gotham
ORGANIZER:Bree Mersday English
STATUS:CONFIRMED
SUMMARY:Bree Mersday English: Rose Gamgee
UID:someuuid
URL:https://bacds.org/bree-mersday-eng
END:VEVENT
END:VCALENDAR
EOL


    eq_or_diff [split(/\r\n/, $got)], [split(/\n/, $expected_1)];

}

sub test_url_endpoint ($test) {
    $test->get_ok('/ical', $series_1);
    ok($test->success, 'got /ical');

    my $got = $test->content;
    $got =~ s/\r\n/\n/g;
    $got =~ s/$UUID_RE/someuuid/g;
    my @got = split "\n", $got;
    my @expected = split "\n", <<'EOL';
BEGIN:VCALENDAR
VERSION:2.0
PRODID:Data::ICal 0.24
X-WR-CALNAME:BACDS Calendar
BEGIN:VEVENT
CATEGORIES:pipesmoking
CATEGORIES:maypole
CLASS:PUBLIC
CREATED:20220428T021805
DESCRIPTION:Rose Gamgee itsa shortdesc 1 無為
DTEND:20220501T220000
DTSTAMP:20220428T021805
DTSTART:20220501T200000
LAST-MODIFIED:20220428T021805
LOCATION:the hall\, 123 Sesame St.\, Gotham
ORGANIZER:Bree Mersday English
STATUS:CONFIRMED
SUMMARY:Bree Mersday English: Rose Gamgee
UID:someuuid
URL:https://bacds.org/bree-mersday-eng
END:VEVENT
BEGIN:VEVENT
CLASS:PUBLIC
CREATED:20220428T021805
DESCRIPTION: new lines shortdesc
DTEND:
DTSTAMP:20220428T021805
DTSTART:20220502T200000
LAST-MODIFIED:20220428T021805
LOCATION:
ORGANIZER:Bywater Trewsday Contra
STATUS:CONFIRMED
SUMMARY:Bywater Trewsday Contra
UID:someuuid
URL:https://bacds.org/bywater-trewsday-contra
END:VEVENT
END:VCALENDAR
EOL

    eq_or_diff \@got, \@expected, '/ical endpoint worked';
}
