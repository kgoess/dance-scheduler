#!/usr/bin/env perl

use 5.16.0;
use warnings;



use bacds::Scheduler::Util::Db qw/get_dbh/;

my $dbh = get_dbh();

create_bands($dbh);

sub create_bands {
    my %bands = (
        'Syncopaths' => [
            'Ryan McKasson',
            'Ashley [Broder] Hoyer',
            'Christa Burch',
            'Jeffrey Spero',
        ],
        'Raven Hill' => [
            'Anne Goess',
            'Burke Trieschmann',
        ],
        'The Flagstones' => [
            'Anne Goess',
            'Will Wheeler',
            'Charlie Hancock',
        ],
        'The Humuhumunukunukuapua & Strathspey Society Band' => [
            'Heather MacKay',
            'Betsy St. Aubin',
            'Bruce Herbold',
            'Patti Cobb',
        ],
        'Whimsical' => [
            'Debra Tayleur',
            'Janette Duncan',
            'Roxanne Oliva',
            'Beth Christian',
        ],
        'The Corn Likkers' => [
            'Ray Chen',
            'Lael Sigal',
            'Lauren Graves',
            'Elijah Chen',
            'Eleanor Chen',
        ],
    );

    foreach my $band_name (sort keys %bands) {
        my $members = $bands{$band_name};
        
        my $new = $dbh->resultset('Band')->new({});

        $new->name($band_name);
        $new->insert;

        my $i = 1;

        foreach my $talent_name (@$members) {
            my @rs = $dbh->resultset('Talent')->search({
                name => $talent_name,
            });
            @rs or die "can't find $talent_name in talent table";
            $new->add_to_talents($rs[0], {
                ordering => $i++,
            });
        }
    }
}
