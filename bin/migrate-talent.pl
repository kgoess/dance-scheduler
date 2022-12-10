#!/usr/bin/env perl

use 5.16.0;
use warnings;

use Data::Dump qw/dump/;

use bacds::Model::Event;# the old CSV schema
use bacds::Scheduler::Util::Db qw/get_dbh/;

my $dbh = get_dbh();

add_talent($dbh);


sub add_talent {
    my ($dbh) = @_;

    my @talent = (
        'Alicia Cover',
        'Anne Goess',
        'Ashley [Broder] Hoyer',
        'Audrey Jaber',
        'Beth Christian',
        'Betsy St. Aubin',
        'Bill Jensen',
        'Bruce Herbold',
        'Burke Trieschmann',
        'Caroline McCaskey',
        'Charlie Hancock',
        'Chip Prince',
        'Christa Burch',
        'Clark Smith',
        'Conall Barber',
        'Craig Johnson ',
        'Dan Warrick',
        'Daniel Steinberg',
        'Dave Wright',
        'David Mostardi',
        'David Newitt',
        'David Strong',
        'Debra Tayleur',
        'Eleanor Chen',
        'Elijah Chen',
        'Ellen Hoffman',
        'Erik Hoffman',
        'Gary Thomas',
        'Harry Leidstrand',
        'Heather MacKay',
        'James Langdell',
        'Janette Duncan',
        'Jeff Spero',
        'Jeffrey Spero',
        'Jon Berger',
        'Judy Linsenberg',
        'Lael Sigal',
        'Larry Unger',
        'Lauren Graves',
        'Laurie Chastain',
        'Lee Anne Welch',
        'Mary Tabor',
        'Patti Cobb ',
        'Paul Kotapish',
        'Ray Chen',
        'Rebecca King',
        'Rob Powell',
        'Robin Lockner',
        'Rodney Miller',
        'Roxanne Oliva',
        'Ryan McKasson',
        'Shira Kammen',
        'Stefan Curl',
        'Sue Jones',
        'Susan Jensen',
        'Susan Worland',
        'Thomas Dewey',
        'Will Wheeler',
        'William Allen',
     );
     foreach my $talent (@talent) {

        my $new = $dbh->resultset('Talent') ->new({});

        say "doing talent $talent";

        $new->name( $talent );
        $new->is_deleted(0);

        # we might want an is_active column
        #$new->is_active( $old->is_active );

        $new->insert;
     }
}

