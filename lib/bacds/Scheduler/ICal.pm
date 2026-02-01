=head1 NAME

bacds::Scheduler::ICal - for exporting events in .ics format

=head1 SYNOPSIS

=head1 DESCRIPTION

iCalendar protocol (RFC 2445, MIME type "text/calendar"), .ics files

https://en.wikipedia.org/wiki/ICalendar

Served under the /ical path.

=head1 METHODS

=cut

package bacds::Scheduler::ICal;

use 5.32.1;
use feature 'signatures';
use warnings;
no warnings 'experimental::signatures';

use Data::ICal;
use Data::ICal::Entry::Event;
use Data::ICal::Entry::TimeZone;
use Data::ICal::Entry::TimeZone::Standard;
use Data::ICal::Entry::TimeZone::Daylight;
use DateTime;
use List::Util qw/first/;

use bacds::Scheduler::Util::Time qw/get_now/;

=head2 events_to_ical($event, $canonical_scheme, $canonical_host)

$event is a bacds::Scheduler::Schema::Result::Event

=cut

sub events_to_ical ($class, $events, $canonical_scheme, $canonical_host) {

    my $calendar = Data::ICal->new(
        calname => 'BACDS Calendar',
        rfc_strict => 1,
    );
    my ($daylight_start, $standard_start) = get_dst_transition_starts();


    # Standard Time
    my $tz_standard = Data::ICal::Entry::TimeZone::Standard->new();
    $tz_standard->add_properties(
        tzoffsetfrom => '-0700',
        tzoffsetto => '-0800',
        tzname => 'PST',
        dtstart => $standard_start,
    );
    # Daylight Savings Time
    my $tz_daylight_savings = Data::ICal::Entry::TimeZone::Daylight->new();
    $tz_daylight_savings->add_properties(
        tzoffsetfrom => '-0800',
        tzoffsetto => '-0700',
        tzname => 'PDT',
        dtstart => $daylight_start,

    );
    # the VTIMEZONE section
    my $vtimezone = Data::ICal::Entry::TimeZone->new();
    $vtimezone->add_properties(
        tzid => 'America/Los_Angeles',,
        #tzurl => "http://zones.stds_r_us.net/tz/US-Eastern"
    );
    $vtimezone->add_entry($tz_daylight_savings);
    $vtimezone->add_entry($tz_standard);

    $calendar->add_entry($vtimezone);

    foreach my $event (@$events) {
        my $vevent = $class->event_to_ical($event, $canonical_scheme, $canonical_host);
        $calendar->add_entry($vevent);
    }

    return $calendar->as_string;

}

=head2 event_to_ical($event, $canonical_scheme, $canonical_host)

$event is a bacds::Scheduler::Schema::Result::Event

=cut

sub event_to_ical ($class, $rs_event, $canonical_scheme, $canonical_host) {
    my $e = $rs_event;

    # see also
    # Data::ICal::DateTime
    # For date parsing and formatting, including denoting "all day"
    # events,

    # is this supported in Data::ICal?
    my $tz = 'America/Los_Angeles';
    # #DTSTART;TZID=America/Los_Angeles:20260201T140000

    my $dtstart = join '',
        $e->start_date =~ s/T.*//r,
        ($e->start_time ? ('T', $e->start_time) : ());
    $dtstart =~ s/[-:]//g;

    my $end_date = $e->end_date || $e->start_date;
    my $dtend = join '',
        $end_date =~ s/T.*//r,
        ($e->end_time ? ('T', $e->end_time) : ('T', '235959')); # is this right? it passes the validator
        # FIXME I don't think 235959 is right...
    $dtend =~ s/[-:]//g;

    my $url = $e->custom_url
        || $e->series && $e->series->get_canonical_url($canonical_scheme, $canonical_host)
        || 'https://bacds.org';

    my $location;
    if ($e->venues && (my $venue = $e->venues->first)) {
        $location = join ', ', $venue->hall_name, $venue->address, $venue->city;
    }

    # lifted this from views/unearth/listings.tt

    my @callers = $e->callers({}, { order_by => 'me.ordering' })->all;
    my @bands   = $e->bands  ({}, { order_by => 'me.ordering' })->all;
    my @talent  = $e->talent ({}, { order_by => 'me.ordering' })->all;

    my $d = '';
    if (my $long_desc = $e->long_desc) {
        $d = $long_desc;
    } else {
        if (@callers) {
            $d .= join ',', map $_->name, @callers;
            if (@bands || @talent) {
                $d .= ' with ';
            }
        }
        if (@bands || @talent) {
            $d .= 'music by ';
            $d .= join ', ', map $_->name, @bands;
            $d .= join ', ', map $_->name, @talent;
            if ($e->and_friends) {
                $d .= '...and friends';
            }
        }
        $d .= ' '.$e->short_desc;
    }
    $d =~ s/\r\n/ /g;
    $d =~ s/\n/ /g;
    $d =~ s/<.+?>/ /g; # html tags
    $d =~ s/  +/ /g; # multiple spaces

    my $name_for_summary = $e->name || $e->series->name;
    if (@callers) {
        $name_for_summary .= ': ';
        $name_for_summary .= join ', ', map $_->name, @callers;
    }

    my $organizer = $e->series
        ? $e->series->name
        : 'BACDS';

    my $vevent = Data::ICal::Entry::Event->new();
    $vevent->add_properties(
        # see
        #  - https://en.wikipedia.org/wiki/ICalendar
        #  - https://icalendar.org/RFC-Specifications/iCalendar-RFC-5545/
        # for details on these fields
        uid => $e->uuid,
        class => 'PUBLIC',
        created => $e->created_ts =~ s/[-:]//gr,
        description => $d,

        dtstart => [
            $dtstart,
            { tzid => $tz }
        ],
        # this is how you do extra params like "tzid"
        #my $todo_props = $todo->add_properties(
        #    attendee => [
        #        'MAILTO:janedoe@host.com',
        #        {
        #            member => [
        #                'MAILTO:projectA@host.com',
        #                'MAILTO:projectB@host.com',
        #            ],
        #        }
        #     ]);
        #ATTENDEE;MEMBER="MAILTO:projectA@host.com","MAILTO:projectB@host.com":MAILT
        # O:janedoe@host.com

        dtend => [
            $dtend,
            { tzid => $tz }
        ],
        'last-modified' => $e->modified_ts =~ s/[-:]//gr,
        location => $location,
        organizer => $organizer,
        dtstamp => get_now()->iso8601 =~ s/[-:]//gr,
        status => $e->is_canceled ? 'CANCELLED' : 'CONFIRMED',
        summary => $name_for_summary,
        url => $url,

        # unused
        # geo => xxx,
        # priority => xxx,
        # sequence => xxx, for revisions
        # transp => xxx, time transparency
    );
    # it looks like CATEGORIES isn't actually used by any real email clients, oh well
    $vevent->add_properties(
        categories => $_->name,
    ) for $e->styles->all;
# nbcds.ical:
# BEGIN:VEVENT
#DTSTART;TZID=America/Los_Angeles:20260201T140000
#DTEND;TZID=America/Los_Angeles:20260201T163000
#DTSTAMP:20260129T060247
#CREATED:20220327T231021Z
#LAST-MODIFIED:20260101T185505Z
#UID:9285-1769954400-1769963400@nbcds.org
#SUMMARY:Sebastopol English Country Dance
#DESCRIPTION:Caller: Lise Dyckman\nBand: Rebecca King (piano)\, Rodney Miller (violin) \nPlease note: Our 3rd and 5th...
#URL:https://nbcds.org/event/sebastopol-english-country-dance-54-2023-01-01-2023-01-15-2023-03-19-2023-07-02-2023-10-01-2026-02-01/
#LOCATION:Wischemann Hall\, 465 Morris St.\, Sebastopol\, CA\, United States
#CATEGORIES:English Country Dance
#ORGANIZER;CN="Tom%20Spittler":MAILTO:tspittler@gmail.com
#GEO:38.4086229;-122.8208861
#X-APPLE-STRUCTURED-LOCATION;VALUE=URI;X-ADDRESS=Wischemann Hall 465 Morris St. Sebastopol CA United States;X-APPLE-RADIUS=500;X-TITLE=465 Morris St.:geo:-122.8208861,38.4086229
#END:VEVENT

    return $vevent;

}

my $_dst_transitions;
my $_dst_transition_year;
sub get_dst_transition_starts {

    my $transition_for_year = get_now()->year;
    if ($_dst_transitions && $_dst_transition_year == $transition_for_year) {
        return @$_dst_transitions;
    }
    $_dst_transition_year = $transition_for_year;

    state %months = (
        Jan => 1,
        Feb => 2,
        Mar => 3,
        Apr => 4,
        May => 5,
        Jun => 6,
        Jul => 7,
        Aug => 8,
        Sep => 9,
        Oct => 10,
        Nov => 11,
        Dec => 12,
    );

    # interestingly there doesn't seem to be any decent way to get this from
    # Perl's DateTime, but see https://www.perlmonks.org/?node_id=602933
    # $ zdump -v America/Los_Angeles -c $(date '+%Y'),$(date -d '+1 year' '+%Y')
    # America/Los_Angeles  -9223372036854775808 = NULL
    # America/Los_Angeles  -9223372036854689408 = NULL
    # America/Los_Angeles  Sun Mar  8 09:59:59 2026 UT = Sun Mar  8 01:59:59 2026 PST isdst=0 gmtoff=-28800
    # America/Los_Angeles  Sun Mar  8 10:00:00 2026 UT = Sun Mar  8 03:00:00 2026 PDT isdst=1 gmtoff=-25200
    # America/Los_Angeles  Sun Nov  1 08:59:59 2026 UT = Sun Nov  1 01:59:59 2026 PDT isdst=1 gmtoff=-25200
    # America/Los_Angeles  Sun Nov  1 09:00:00 2026 UT = Sun Nov  1 01:00:00 2026 PST isdst=0 gmtoff=-28800
    # America/Los_Angeles  9223372036854689407 = NULL
    # America/Los_Angeles  9223372036854775807 = NULL
    #
    # we want to transorm that into these values:
    # daylight: dtstart => '20260308T100000',
    # standard: dtstart => '20261101T090000',

    my $transition_for_year_next = $transition_for_year + 1;
    my $output = `zdump -v America/Los_Angeles -c $transition_for_year,$transition_for_year_next`
        or die "zdump failed! $!";

    my @output = split "\n", $output;

    my $daylight_start = first { /isdst=1/ } @output;
    my $standard_start = first { /isdst=0/ } reverse @output;

    my ($tzname, $UT_dow, $UT_mon, $UT_day, $UT_time, $UT_year, $ut, $equals, $PT_dow, $PT_mon, $PT_day, $PT_time, $PT_year, $PT_tzname, $idsdt, $gmtoff);
    my ($hour, $min, $sec, $date_obj);

    ($tzname, $UT_dow, $UT_mon, $UT_day, $UT_time, $UT_year, $ut, $equals, $PT_dow, $PT_mon, $PT_day, $PT_time, $PT_year, $PT_tzname, $idsdt, $gmtoff) = split /\s+/, $daylight_start;


    ($hour, $min, $sec) = split /:/, $UT_time;
    $date_obj = DateTime->new(
        year       => $UT_year,
        month      => $months{$UT_mon},
        day        => $UT_day,
        hour       => $hour,
        minute     => $min,
        second     => $sec,
        time_zone  => 'UTC',
    );
    my $daylight_start_str = $date_obj->ymd('') . 'T' . $date_obj->hms('');

    ($tzname, $UT_dow, $UT_mon, $UT_day, $UT_time, $UT_year, $ut, $equals, $PT_dow, $PT_mon, $PT_day, $PT_time, $PT_year, $PT_tzname, $idsdt, $gmtoff)
         = split /\s+/, $standard_start;
    ($hour, $min, $sec) = split /:/, $UT_time;
    $date_obj = DateTime->new(
        year       => $UT_year,
        month      => $months{$UT_mon},
        day        => $UT_day,
        hour       => $hour,
        minute     => $min,
        second     => $sec,
        time_zone  => 'UTC',
    );
    my $standard_start_str = $date_obj->ymd('') . 'T' . $date_obj->hms('');

    $_dst_transitions = [$daylight_start_str, $standard_start_str];

    return $daylight_start_str, $standard_start_str;
}

1;
