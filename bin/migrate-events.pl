#!/usr/bin/env perl

use 5.16.0;
use warnings;


use bacds::Model::Event;# the old CSV schema

use bacds::Scheduler::Util::Db qw/get_dbh/;

my $dbh = get_dbh();

create_events();

sub create_events {

    # this is a mapping of loc+type in the old schedule csv table
    # to the new series table, by name
    my %series_lookup = (
        'CCB-CONTRA' => 'Berkeley Contra',
        'SF-CONTRA' => 'San Francisco Contra',
        'FUM-CONTRA' => 'Palo Alto Contra', # ?
        'HVC-CONTRA' => 'Hayward Contra',
        'FSJ-CONTRA' => 'South Bay Contra',
        'ASE-ENGLISH' => 'Peninsula English',
        'CCB-ENGLISH' => 'Berkeley English',
        # ???
        #'CCB-ENGLISH' => 'Berkeley Fourth Saturday Experienced Dance',
        'SJP-ENGLISH' => 'San Francisco English',
        'FSJ-ENGLISH' => 'San Jose English',
        'HPP-WOODSHED' => 'Atherton Woodshed',
        'ONLINE-ONLINE ENGLISH DANCE' => 'Odd Sundays Online',
        'ONLINE-ENGLISH' => 'Odd Sundays Online',
        'ONLINE-ONLINE ENGLISH DANCE' => 'Odd Sundays Online',
        'ONLINE-ONLINE Concert &amp; Dance' => 'Online Concert',
        'SSU-ENGLISH/CAMP' => 'Hey Days English Week',
        'MON-FAMILY/CAMP' => 'Family Week',
        'JPC-CONTRA/CAMP' => 'Balance the Bay',
        'SME-ENGLISH/REGENCY' => 'English Regency',
    );

    my @old_events = bacds::Model::Event->load_all;

    foreach my $old (@old_events) {
        my $new = $dbh->resultset('Event')->new({});

        my $name = join ' ', map { $old->$_ } qw/startday type loc leader/ ;

        say "doing $name";

        # there's not really a name in the old schema
        $new->name($name);
        $new->start_time( $old->startday );
        $new->end_time( $old->endday )
            if $old->endday;
        $new->is_camp( $old->type ? 1 : 0 );
        $new->long_desc( $old->leader . ' with ' .$old->band );
        $new->short_desc( $old->leader );

        my $key = join '-', $old->loc, $old->type;
        my $loc_str = $series_lookup{$key}
            or die "can't lookup series for '$key'";

        my $rs = $dbh->resultset('Series')->search({
                name => { -like => "$loc_str%" },
        }) or die "Series->search $loc_str% failed";

        my $series_obj = $rs->next
            or die "no next for $loc_str";

        $new->series_id( $series_obj->series_id );

        $new->insert;

        my @old_styles;
        my $old_style = $old->type;
        if ($old_style =~ /ONLINE/) {
            push @old_styles, 'ONLINE' # fudging e.g. ONLINE Concert &amp; Dance
        } elsif ($old_style eq 'ENGLISH/CAMP') {
            push @old_styles, 'ENGLISH', 'CAMP';
        } elsif ($old_style eq 'FAMILY/CAMP') {
            push @old_styles, 'FAMILY', 'CAMP';
        } elsif ($old_style eq 'CONTRA/CAMP') {
            push @old_styles, 'CONTRA', 'CAMP';
        } elsif ($old_style eq 'ENGLISH/REGENCY') {
            push @old_styles, 'ENGLISH', 'REGENCY';
        } else {
            push @old_styles, $old_style;
        }

        my $i = 1;
        foreach my $style (@old_styles) {
            my @rs = $dbh->resultset('Style')->search({
                name => $style,
            });
            @rs or die "can't find $style in styles table";
            $new->add_to_styles($rs[0], {
                ordering => $i++,
            });
        }
    }
}

