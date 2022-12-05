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

=head2 get_events

Loads events within the date range, preloading all the related tables the
dancefinder needs to display the input form.

=cut

sub get_events {
    my ($class, %args) = @_;

    my $dbh = get_dbh();

    my @search_args;
    # These prefetches means all the data is fetched with one big
    # JOIN, you can verify that by adding debug=>1 in the
    # get_dbh call above
    my @prefetches = (
        {event_callers_maps => 'caller'},
        {event_venues_maps => 'venue'},
        {event_band_maps => 'band'},
        {event_talent_maps => 'talent'},
        {event_styles_maps => 'style'},
        {event_band_maps => {band => { band_memberships => 'talent'}}},
    );


    my $now = get_now();

    my $rs = $dbh->resultset('Event')->search(
        {
            start_date => { '>=' => $now->ymd },
            @search_args,
        },
        {
        # wrt join and prefetch see:
        # https://metacpan.org/dist/DBIx-Class/view/lib/DBIx/Class/Manual/Cookbook.pod#Using-joins-and-prefetch
        #    join => \@related_tables,
            prefetch => \@prefetches,
        },
    );

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
        venues => \%venuehash,
        bands => \%bandhash,
        musos => \%musohash,
        styles => \%stylehash,
    };
}

1;
