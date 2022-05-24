#!/usr/bin/env perl

use 5.16.0;
use warnings;

use bacds::Model::Venue;# the old CSV schema

use bacds::Scheduler::Util::Db qw/get_dbh/;

my $dbh = get_dbh();

create_venues($dbh);

sub create_venues {
    my ($dbh) = @_;

    my @old_venues = bacds::Model::Venue->load_all;
    my $new = $dbh->resultset('Venue')->new({});

    my %venue_id;

    foreach my $old (@old_venues) {

        # ZOOM Concert, ZOOM Contra, ZOOM Waltz, weren't really venues
        # I think were an early attempt to handle ZOOM stuff
        next if $old->vkey =~ /^ZOOM \w+/;

        my $new = $dbh->resultset('Venue') ->new({});

        $new->vkey( $old->vkey );
        $new->hall_name( $old->hall );
        $new->address ( $old->address );
        $new->city ( $old->city );

        my $comment = '';
        if ($old->zip =~ /[^0-9]/) {
            $comment = $old->zip;
        } else {
            $new->zip( $old->zip );
        }

        # we might want an is_active column
        #$new->is_active( $old->is_active );

        $new->comment( $comment . "\n". $old->comment );

        $new->insert;

        $venue_id{$new->venue_id} = $new->vkey;
    }
}
