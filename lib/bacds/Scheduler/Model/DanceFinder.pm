=head1 NAME

bacds::Scheduler::Model::DanceFinder

=head1 DESCRIPTION

This is the db access stuff for the dancefinder

=head2 METHODS

=cut

package bacds::Scheduler::Model::DanceFinder;

use 5.16.0;
use warnings;

use Data::Dump qw/dump/;

use bacds::Scheduler::Util::Db qw/get_dbh/;
use bacds::Scheduler::Util::Time qw/get_now/;

=head2 related_entities_for_upcoming_events

Loads events within the date range, preloading all the related tables the
dancefinder needs to display the input form.

=cut

sub related_entities_for_upcoming_events {
    my ($class, %args) = @_;

    my $rs = _all_upcoming_events();

    my (%stylehash, %venuehash, %bandhash, %musohash, %callerhash);
    while (my $event = $rs->next) {
        # grab the callers
        my $callers = $event->callers;
        while (my $caller = $callers->next) {
            $callerhash{$caller->caller_id} = $caller;
        }
        # grab the venues
        my $venues = $event->venues;
        while (my $venue = $venues->next) {
            $venuehash{$venue->venue_id} = $venue;
        }
        if (my $bands = $event->bands) {
            # grab the bands
            while (my $band = $bands->next) {
                $bandhash{$band->band_id} = $band;
                # and the band members
                if (my $talentii = $band->talents) {
                    while (my $talent = $talentii->next) {
                        $musohash{$talent->talent_id} = $talent;
                    }
                }
            }
        }
        # and any unattached musos
        if (my $talentii = $event->talent) {
            while (my $talent = $talentii->next) {
                $musohash{$talent->talent_id} = $talent
            }
        }
        # grab the styles
        my $styles = $event->styles;
        while (my $style = $styles->next) {
            $stylehash{$style->style_id} = $style;
        }
    }

    return {
        callers => \%callerhash,
        venues  => \%venuehash,
        bands   => \%bandhash,
        musos   => \%musohash,
        styles  => \%stylehash,
    };
}

# this is a simpler version of do_search, it takes no args and it doesn't do
# the subselect make sure all the related tables are loaded whether they match
# the args or not, so this is more suited for the front-page display
sub _all_upcoming_events {

    my $dbh = get_dbh(); #debug => 1);

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

    my $start_date = get_now()->ymd;

    # wrt join and prefetch see:
    # https://metacpan.org/dist/DBIx-Class/view/lib/DBIx/Class/Manual/Cookbook.pod#Using-joins-and-prefetch
    my $rs = $dbh->resultset('Event')->search(
        {
            start_date => { '>=' => $start_date },
        },
        {
            prefetch => \@prefetches,
        },
    );

    return $rs
}

=head2 search_events

This one searches the events table, takes a bunch of args, and makes sure that
all the related entities come back with the events.

Returns a $rs for you to call `->all` on. You can't do `->next` because of this
warning:

    DBIx::Class::ResultSet::_construct_results(): Unable to properly collapse
    has_many results in iterator mode due to order criteria - performed an
    eager cursor slurp underneath. Consider using ->all() instead at

=cut

sub search_events {
    my ($class, %args) = @_;

    my $start_date_arg = delete $args{start_date};
    my $end_date_arg   = delete $args{end_date};
    my $caller_arg     = delete $args{caller}     || [];
    my $venue_arg      = delete $args{venue}      || [];
    my $band_arg       = delete $args{band}       || [];
    my $muso_arg       = delete $args{muso}       || [];
    my $style_arg      = delete $args{style}      || [];
    die "unrecognized args in call to get_events: ".join(', ', sort keys %args)
        if %args;

    my $dbh = get_dbh(); #debug => 1);

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

    my @joins = (
        @$caller_arg ? 'event_callers_maps' : (),
        @$venue_arg ? 'event_venues_maps' : (),
        @$style_arg ? 'event_styles_maps' : (),
        @$muso_arg ? 'event_talent_maps' : (),
        @$band_arg ? 'event_band_maps' : (),
    );

    my $start_date = $start_date_arg || get_now()->ymd;

    # wrt join and prefetch see:
    # https://metacpan.org/dist/DBIx-Class/view/lib/DBIx/Class/Manual/Cookbook.pod#Using-joins-and-prefetch
    my $subquery = $dbh->resultset('Event')->search(
        {
            @$caller_arg ? ('event_callers_maps.caller_id' => $caller_arg) : (),
            @$venue_arg  ? ('event_venues_maps.venue_id'   => $venue_arg)  : (),
            @$style_arg  ? ('event_styles_maps.style_id'   => $style_arg)  : (),
            @$muso_arg   ? ('event_talent_maps.talent_id'  => $muso_arg)   : (),
            @$band_arg   ? ('event_band_maps.band_id'      => $band_arg)   : (),
            start_date => $end_date_arg 
                ? { '-between' => [$start_date, $end_date_arg] }
                : { '>=' => $start_date },
        },
        {
            join => \@joins,
            select => 'event_id',
        },
    );
    my $query = $dbh->resultset('Event')->search(
        {
            'me.event_id' => { -in => $subquery->as_query },
        },
        {
            order_by => 'start_date',
            prefetch => \@prefetches,
        },
    );

    return $query;
}


1;
