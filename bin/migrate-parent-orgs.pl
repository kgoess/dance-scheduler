#!/usr/bin/env perl

use 5.16.0;
use warnings;

use Data::Dump qw/dump/;

use bacds::Model::Event;# the old CSV schema
use bacds::Scheduler::Util::Db qw/get_dbh/;

my $dbh = get_dbh();

add_parent_orgs($dbh);


sub add_parent_orgs {
    my ($dbh) = @_;

    my @parent_orgs = (
        [ 'BACDS', 'Bay Area Country Dance Society' ],
        [ 'NBCDS', 'North Bay Country Dance Society' ],
        [ 'TDSC', 'Traditional Dancers of Santa Cruz' ],
        [ 'MCDC', 'Monterey Country Dance Community' ],
    );

    foreach my $row (@parent_orgs) {
        my ($abbr, $name) = @$row;

       my $new = $dbh->resultset('ParentOrg') ->new({});

       say "doing parent_org $name";

       $new->full_name( $name );
       $new->abbreviation( $abbr );
       $new->is_deleted(0);

       # we might want an is_active column
       #$new->is_active( $old->is_active );

       $new->insert;
    }
}

