=head1 NAME

bacds::Scheduler::Model::SeriesLister - fetch data for upcoming events in a series

=head1 SYNOPSIS

    $data = $c->get_upcoming_events_for_series(
        # one of these two:
        series_id => 123,
        series_xid => 'BERK-ENGLISH',
    );

or

    $data = $c->get_event_details(
        event_id => 123,
    );

=head1 DESCRIPTION

This is replacing the functions of the old serieslists.pl.

=head1 METHODS

=cut

package bacds::Scheduler::Model::SeriesLister;

use 5.16.0;
use warnings;

use Carp;
use Data::Dump qw/dump/;
use Dancer2::Serializer::JSON qw/to_json/;
use Encode qw/decode_utf8/;

use bacds::Scheduler::Util::Db qw/get_dbh/;
use bacds::Scheduler::Util::Time qw/get_today/;

=head2 get_upcoming_events_for_series

args can be either:

 - series_xid e.g. BERK-CONTRA
 - series_id: e.g. 12345

=cut

sub get_upcoming_events_for_series {
    my ($class, %args) = @_;

    croak "missing required args in call to get_upcoming_events_for_series, ".
          "need either series_id or series_xid "
        unless ($args{series_id} || $args{series_xid});

    my $dbh = get_dbh(debug => 0);

    my $series;

    my @search_arg =
        $args{series_xid}
        ? (series_xid => $args{series_xid})
        : (series_id => $args{series_id})
    ;

    $series = $dbh->resultset('Series')->find(
        {
            is_deleted => 0,
            @search_arg,
        },
    ) or croak "get_upcoming_events_for_series can't ".
                "find any series for @search_arg";

    # These prefetches means all the data is fetched with one big
    # JOIN, you can verify that by adding debug=>1 in the
    # get_dbh call above
    my @prefetches = (
        {event_callers_maps => 'caller'},
        {event_styles_maps => 'style'},
        {event_talent_maps => 'talent'},
        {event_venues_maps => 'venue'},
        {event_band_maps => {band => { band_memberships => 'talent'}}},
    );

    my @events = $dbh->resultset('Event')->search(
        {
            'me.is_deleted' => 0,
            'me.series_id' => $series->series_id,
            'me.start_date' => { '>=' => get_today()->ymd },
        },
        {
            prefetch => \@prefetches,
            order_by => 'start_date',
        },
    );

    return {
        series => $series,
        events => \@events,
    }
}

=head2 get_event_details

Display the data for this one event.

Returns the same data structure as get_upcoming_events_for_series

=cut 

sub get_event_details {
    my ($class, %args) = @_;

    my $event_id = $args{event_id}
        or croak "missing arg event_id in call to get_event_details";

    my $dbh = get_dbh(debug => 0);

    # These prefetches means all the data is fetched with one big
    # JOIN, you can verify that by adding debug=>1 in the
    # get_dbh call above
    my @prefetches = (
        'series',
        {event_callers_maps => 'caller'},
        {event_styles_maps => 'style'},
        {event_talent_maps => 'talent'},
        {event_venues_maps => 'venue'},
        {event_band_maps => {band => { band_memberships => 'talent'}}},
    );

    my $event = $dbh->resultset('Event')->find(
        {
            #ask for an event explicitly and we'll give it to you even
            #if it's deleted
            #is_deleted => 0,
            event_id => $event_id,
        },
        {
            prefetch => \@prefetches,
        },
    );

    return {
        series => $event->series,
        events => [$event],
        ldjson => generate_ldjson($event), # might be empty
    }
}


sub generate_ldjson {
    shift if $_[0] eq __PACKAGE__;
    my ($event) = @_;

    my $date = $event->start_date->ymd;
    my $venue = $event->venues->first
        or return '';
    my $leaders = join ', ', map $_->name, $event->callers;
    my $bands = join ', ', map $_->name, $event->bands;

    my $start_time = $event->start_time
        ? $event->start_time
        : '00:00:00';
    my $end_time = $event->end_time
        ? $event->end_time
        : '00:00:00';

    my $comments = $event->short_desc;

    state $ok_dance_types = { map { $_ => 1 } qw/
        REGENCY
        FAMILY
        ENGLISH
        CONTRA
        CEILIDH
    /};
    my $nice_dance_type = join '/', map ucfirst lc, grep $ok_dance_types->{$_}, map $_->name, $event->styles;
    $nice_dance_type //= 'English Country'; # likely to be correct :-/

    #my $offer_url = "https://$ENV{HTTP_HOST}$ENV{DOCUMENT_URI}";
    my $offer_url = bacds::Scheduler->ssi_uri_for({event_id => $event->event_id});

    my $start = join 'T', $date, $start_time;
    my $end   = join 'T', $date, $end_time;


    # new fields eventAttendanceMode: could be Offline, Online or Mixed
    # new field eventStatus could be:
    # 		EventCancelled
    # 		EventMovedOnline
    # 		EventPostponed
    # 		EventRescheduled
    # 		EventScheduled
    # just handling Cancelled to start with
    my $event_status_url = $event->is_canceled
        ? 'https://schema.org/EventCancelled'
        : 'https://schema.org/EventScheduled';

    my %json_data = (
       '@context'  => 'http://schema.org',
       '@type'    => ['Event','DanceEvent'],
        name        => "$nice_dance_type Dancing, calling by $leaders to the music of $bands",
        startDate   => $start,
        endDate     => $end,
        eventAttendanceMode => 'https://schema.org/OfflineEventAttendanceMode',
        eventStatus => $event_status_url,
        organizer => {
           '@context' => 'http://schema.org',
           '@type'    => 'Organization',
            name      => 'Bay Area Country Dance Society',
            url       => 'https://www.bacds.org/'
        },
        location => {
           '@context' => 'http://schema.org',
           '@type'    => 'Place',
            name      => $venue->hall_name,
            address => {
               '@type'          => "PostalAddress",
                streetAddress   => $venue->address,
                addressLocality => $venue->city,
                postalCode      => $venue->zip,
                addressRegion   => "California",
                addressCountry  => "USA"
            }
        },
        description => "$nice_dance_type Dancing at ".$venue->hall_name." in ".$venue->city.". ".
            "Everyone welcome, beginners and experts! No partner necessary. ".
            "$comments (Prices may vary for special events or workshops. Check ".
            "the calendar or website for specifics.)",
        image => 'https://www.bacds.org/graphics/bacdsweblogomed.gif',
        performer => [
            {
               '@type' => 'MusicGroup',
                name   => $bands,
            },
            {
               '@type' => 'Person',
                name => $leaders,
            }
        ],
        offers => [
        {
            '@type' => "Offer",
            name => "supporters",
            price => "25.00",
            priceCurrency => "USD",
            url => $offer_url,
            availability => "http://schema.org/LimitedAvailability",
            validFrom  => $date,
        },{
            '@type' => 'Offer',
            name => 'non-members',
            price => '20.00',
            priceCurrency => 'USD',
            url => $offer_url,
            availability => 'http://schema.org/LimitedAvailability',
            validFrom => $date,
        },{
            '@type' => 'Offer',
            name => 'members',
            price => '15.00',
            priceCurrency => 'USD',
            url => $offer_url,
            availability => 'http://schema.org/LimitedAvailability',
            validFrom => $date,
        },{
            '@type' => 'Offer',
            name => 'students or low-income or pay what you can',
            price => '6.00',
            priceCurrency => 'USD',
            url => $offer_url,
            availability => 'http://schema.org/LimitedAvailability',
            validFrom => $date
        }
        ]
    );

    # decode to logical characters, which is what the template expects
    my $json_str = decode_utf8 Dancer2::Serializer::JSON::to_json(\%json_data, { pretty => 1 });
    return <<EOL;
    <script type="application/ld+json">
    $json_str
    </script>
EOL
}

1;
