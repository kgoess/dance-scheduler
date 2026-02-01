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

use bacds::Scheduler::Util::Time qw/get_now/;

=head2 events_to_ical($event, $canonical_scheme, $canonical_host)

$event is a bacds::Scheduler::Schema::Result::Event

=cut

sub events_to_ical ($class, $events, $canonical_scheme, $canonical_host) {

    my $calendar = Data::ICal->new(
        calname => 'BACDS Calendar',
        rfc_strict => 1,
    );
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
    my $tz = 'TZID=America/Los_Angeles';
    # TZID=America/Los_Angeles:20260201T140000

    my $dtstart = join '', 
#        $tz, ':',
        $e->start_date =~ s/T.*//r,
        ($e->start_time ? ('T', $e->start_time) : ());
    $dtstart =~ s/[-:]//g;

    my $dtend = join '', 
#        $tz, ':',
        $e->end_date =~ s/T.*//r,
        ($e->end_time ? ('T', $e->end_time) : ());
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
        } else {
            if (@bands || @talent) {
                $d .= 'Music by ';
                $d .= join ', ', map $_->name, @bands;
                $d .= join ', ', map $_->name, @talent;
                if ($e->and_friends) {
                    $d .= '...and friends';
                }
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

        dtstart => $dtstart,
        dtend => $dtend,
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





1;
