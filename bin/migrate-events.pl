#!/usr/bin/env perl

use 5.16.0;
use warnings;

use Data::Dump qw/dump/;

use bacds::Model::Event;# the old CSV schema

use bacds::Scheduler::Util::Db qw/get_dbh/;

# this is a mapping of loc+type in the old schedule csv table
# to the new series table, by name
my %Series_Lookup = (
    'CCB-CONTRA' => 'Berkeley Contra',
    'GNC-CONTRA' => 'Berkeley Contra',
    'STC-CONTRA' => 'Berkeley Contra',
    'CCB-CONTRA/WORKSHOP' => 'Berkeley Contra',
    'STALB-CONTRA/WORKSHOP' => 'Berkeley Contra',
    'STALB-CONTRA' => 'Berkeley Contra',
    'CCB-WORKSHOP/HAMBO' => 'Berkeley Contra',
    'STALB-WORKSHOP/HAMBO' => 'Berkeley Contra',
    'CCB-CONTRAWORKSHOP/WALTZ' => 'Berkeley Contra',
    'CCB-ECDWORKSHOP/WALTZ' => 'Berkeley Contra',
    'CCB-CONTRA/JAM' => 'Berkeley Contra',
    'SF-CONTRA' => 'San Francisco Contra',
    'SF-CONTRA/SPECIAL' => 'San Francisco Contra',
    'SF-CONTRAWORKSHOP' => 'San Francisco Contra',
    'SF-BARN DANCE' => 'San Francisco Contra',
    'FUM-CONTRA' => 'Palo Alto Contra', # ?
    'FUM-CONTRA/SPECIAL' => 'Palo Alto Contra',
    'FUM-CONTRA/WALTZ' => 'Palo Alto Contra',
    'MT-WORKSHOP/HAMBO' => 'Palo Alto Contra',
    'MT-CONTRA' => 'Palo Alto Contra',
    'MT-CONTRA/SPECIAL' => 'Palo Alto Contra',
    'FUM-CONTRA/WALTZ/SPECIAL' => 'Palo Alto Contra',
    'FUM-CONTRA/WORKSHOP/SPECIAL' => 'Palo Alto Contra',
    'FUM-CONTRA/WORKSHOP' => 'Palo Alto Contra',
    'SME-CONTRA' => 'Palo Alto Contra',
    'FUM-ENGLISH/SPECIAL' => 'Palo Alto English',
    'FUM-WORKSHOP/HAMBO' => 'Palo Alto English',
    'SBE-CONTRA' => 'Palo Alto Contra',
    'SFV-CONTRA/SPECIAL' => 'Palo Alto Contra',
    'HVC-CONTRA' => 'Hayward Contra',
    'ONLINE-ONLINE Hayward Contra' => 'Hayward Contra',
    'FSJ-CONTRA' => 'South Bay Contra Dance Series',
    'FSJ-SPECIAL' => 'South Bay Contra Dance Series',
    'FSJ-CONTRA/SPECIAL' => 'South Bay Contra Dance Series',
    'FSJ-CONTRA/JAM' => 'South Bay Contra Dance Series',
    'FSJ-CONTRA/SPECIAL/WORKSHOP' => 'South Bay Contra Dance Series',
    'FSJ-FAMILY' => 'South Bay Contra Dance Series',
    'GSP-FAMILY' => 'South Bay Contra Dance Series',
    'CCB-ENGLISH' => 'Berkeley English',
    'GNC-ENGLISH' => 'Berkeley English',
    'GNC-ENGLISH/SPECIAL' => 'Berkeley English',
    'CCB-ENGLISH/JAM' => 'Berkeley English',
    'CCB-ENGLISH/WORKSHOP' => 'Berkeley English',
    'GNC-ENGLISH/WORKSHOP' => 'Berkeley English',
    'GNC-WORKSHOP' => 'Berkeley English',
    'CCB-ENGLISH/COUPLE' => 'Berkeley English',
    'STC-ENGLISH' => 'Berkeley English',
    'STC-ENGLISH/WORKSHOP' => 'Berkeley English',
    'STC-ENGLISH/WORKSHOP/SPECIAL' => 'Berkeley English',
    'CCB-ENGLISH/CONTRA' => 'Berkeley English',
    'CCB-ENGLISH/WALTZ' => 'Berkeley English',
    'CCB-ENGLISH/SPECIAL' => 'Berkeley English',
    'CCB-ENGLISH/WORKSHOP/SPECIAL' => 'Berkeley English',
    'CCB-WALTZ/WORKSHOP' => 'Berkeley English',
    'SMM-ENGLISH' => 'Berkeley English',
    'FBH-ENGLISH' => 'Berkeley Fourth Saturday Experienced Dance',
    'FBH-ENGLISH/WORKSHOP' => 'Berkeley Fourth Saturday Experienced Dance',
    'FUO-ENGLISH' => 'Berkeley Fourth Saturday Experienced Dance',
    'CCB-WALTZ' => 'Berkeley English',
    'CCB-SINGING' => 'Berkeley English',
    'GNC-SINGING' => 'Berkeley English',
    'CCB-SINGING/ENGLISH' => 'Berkeley English',
    'STALB-SINGING' => 'Berkeley English',
    'STALB-ENGLISH' => 'Berkeley English',
    'STALB-ENGLISH/WORKSHOP' => 'Berkeley English',
    'CCB-SINGING/ENGLISH/WORKSHOP' => 'Berkeley English',
    # ASE,FBC,MT,FHL,SME,STM are all Peninsula English if Tue/Wed/Thu
    'ASE-ENGLISH' => 'Peninsula English (Palo Alto)',
    'AST-ENGLISH' => 'Peninsula English (Palo Alto)',
    'JLS-ENGLISH' => 'Peninsula English (Palo Alto)',
    'ASE-ENGLISH/SPECIAL' => 'Peninsula English (Palo Alto)',
    'STM-ENGLISH' => 'Peninsula English (Palo Alto)',
    'FLX-ENGLISH' => 'Peninsula English (Palo Alto)',
    'MT-ENGLISH' => 'Peninsula English (Palo Alto)',
    'MT-ENGLISH' => 'Peninsula English (Palo Alto)',
    'MT-ENGLISH/WORKSHOP' => 'Peninsula English (Palo Alto)',
    'MT-ENGLISH/SPECIAL/WORKSHOP' => 'Peninsula English (Palo Alto)',
    'MT-ENGLISH/SPECIAL' => 'Peninsula English (Palo Alto)',
    'MT-ENGLISH/WALTZ/WORKSHOP/SPECIAL' => 'Peninsula English (Palo Alto)',
    'FHL-ENGLISH' => 'Peninsula English (Palo Alto)',
    'SME-ENGLISH' => 'Palo Alto Friday English Dance',
    'SME-ENGLISH WORKSHOP' => 'Palo Alto Friday English Dance',
    'SME-ENGLISH/WORKSHOP' => 'Palo Alto Friday English Dance',
    'SME-ENGLISH/SPECIAL' => 'Palo Alto Friday English Dance',
    'SME-ENGLISH/REGENCY/SPECIAL' => 'Palo Alto Friday English Dance',
    'FBC-ENGLISH' => 'Palo Alto Friday English Dance',
    'FBC-CONTRA' => 'Palo Alto Contra',
    # ???
    #'CCB-ENGLISH' => 'Berkeley Fourth Saturday Experienced Dance',
    'SJP-ENGLISH' => 'San Francisco Saturday English Dance',
    'SPC-ENGLISH' => 'San Francisco Saturday English Dance',
    'DGK-ENGLISH' => 'San Francisco Saturday English Dance',
    'DGK-ENGLISH/CEILIDH' => 'San Francisco Saturday English Dance',
    'FSJ-ENGLISH' => 'San Jose English',
    'FSJ-ENGLISH/SPECIAL' => 'San Jose English',
    'FSJ-ENGLISH/CONTRA' => 'San Jose English',
    'COY-ENGLISH' => 'San Jose English', # just guessing?
    'HPP-WOODSHED' => 'Los Altos Second-Monday Woodshed',
    'STM-WOODSHED' => 'Los Altos Second-Monday Woodshed',
    'SME-WOODSHED' => 'Los Altos Second-Monday Woodshed',
    'ONLINE-ONLINE' => 'Odd Sundays Online',
    'ONLINE-ONLINE ENGLISH DANCE' => 'Odd Sundays Online',
    'ONLINE-ENGLISH' => 'Odd Sundays Online',
    'ONLINE-ONLINE ENGLISH DANCE' => 'Odd Sundays Online',
    'ONLINE-ONLINE Concert &amp; Dance' => 'Online Concert',
    'ONLINE-ONLINE Concert & Dance' => 'Online Concert',
    'ONLINE-ONLINE Waltz' => 'Online Waltz',
    'ONLINE-ONLINE Workshop' => 'Online Workshop',
    'ONLINE-ONLINE Caller Workshop' => 'Online Caller Workshop',
    'ONLINE-ONLINE Concert' => 'Online Concert',
    'ONLINE-ONLINE Contra Jam' => 'Online Contra Jam',
    'ONLINE-ONLINE Contra' => 'Online Contra',
    'ONLINE-ONLINE Concert/Contra/Party!' => 'Online Concert/Contra/Party!',
    'SSU-ENGLISH/CAMP' => 'Hey Days English Week',
    'SSU-ENGLISH CAMP HEY DAYS' => 'Hey Days English Week',
    'SSU-ENGLISH/SINGING/DISPLAY/CAMP' => 'Hey Days English Week',
    'ONLINE-ONLINE English Camp' => 'Hey Days English Week',
    'BR-CAMP/ENGLISH/MUSIC' => 'Hey Days English Week',
    'MEN-CAMP/ENGLISH/MUSIC/DISPLAY' => 'Hey Days English Week',
    'BR-ENGLISH CAMP FALL FROLICK' => 'Fall Frolick',
    'BR-ENGLISH/CAMP' => 'Fall Frolick',
    'ONLINE-ENGLISH/CAMP' => 'Fall Frolick',
    'MON-ENGLISH/CAMP/SPECIAL' => 'Fall Frolick',
    'MON-ENGLISH/CAMP' => 'Fall Frolick',
    'MON-CAMP/ENGLISH/MUSIC/DISPLAY' => 'Fall Frolick',
    'FBH-ENGLISH/SPECIAL' => 'Fall Ball',
    'FBH-ENGLISH/SPECIAL/WORKSHOP' => 'Fall Ball',
    'SMT-ENGLISH/SPECIAL' => 'Fall Ball',
    'SMT-ENGLISH/SPECIAL/WORKSHOP' => 'Fall Ball',
    'SMT-ENGLISH/WORKSHOP/SPECIAL' => 'Fall Ball',
    'SMT-ENGLISH/WORKSHOP' => 'Fall Ball',
    'MON-FAMILY/CAMP' => 'Family Week',
    'MON-ENGLISH/CAMP/SPECIAL/WEEKEND' => 'Family Week',
    'MON-CONTRA/ENGLISH/DISPLAY/CRAFTS/CAMP/SPECIAL' => 'Family Week',
    'FHS-CAMP/FAMILY/ENGLISH/MUSIC/DISPLAY' => 'Family Week',
    'FHS-CAMP/CONTRA/ENGLISH/FAMILY/CRAFTS' => 'Family Week',
    'MON-CAMP/CONTRA/ENGLISH/IRISH/INTERNATIONAL/FAMILY/CRAFTS' => 'Family Week',
    'MON-CAMP/ENGLISH/CONTRA/SINGING/MUSIC' => 'Family Week',
    'FHS-CAMP/CONTRA/ENGLISH/IRISH/INTERNATIONAL/FAMILY/CRAFTS' => 'Family Week',
    'ONLINE-ONLINE Family Week Gathering' => 'Family Week',
    'JPC-CONTRA/CAMP' => 'Balance the Bay',
    'JPC-CONTRA/SPECIAL' => 'Balance the Bay',
    'PRC-CONTRA/CAMP/SPECIAL' => 'Balance the Bay',
    'PRC-CONTRA/SPECIAL' => 'Balance the Bay',
    'PRC-CONTRA' => 'Balance the Bay',
    'JPC-BALANCE THE BAY SPECIAL CONTRA WEEKEND' => 'Balance the Bay',
    'JPC-CONTRA/CAMP/SPECIAL' => 'Balance the Bay',
    'JPC-CAMP/CONTRA/SPECIAL' => 'Balance the Bay',
    'SME-ENGLISH/REGENCY' => 'English Regency',
    'STM-ENGLISH/REGENCY' => 'English Regency',
    'ACC-ENGLISH' => 'Arlington Community Church English',
    'FSJ-TEEN CONTRA' => 'Teen Contra',
    'FSJ-FAMILY/CONTRA' => 'Family Contra',
    'HVC-FAMILY/CONTRA' => 'Family Contra',
    'HVC-CONTRA/FAMILY' => 'Family Contra',
    'RHM-CONTRA/SPECIAL' => 'Contra College',
    'RHM-CONTRA/WORKSHOP/SPECIAL' => 'Contra College',
    'FUM-CONTRA/WORKSHOP/SPECIAL' => 'Contra College',
    'WCP-CONTRA/WORKSHOP/SPECIAL' => 'Contra College',
    'WCP-CONTRA/SPECIAL' => 'Contra College',
    'WCP-CONTRA' => 'Contra College',
    'WCP-CONTRA/WORKSHOP' => 'Contra College',
    'WCP-CONTRA/WORKSHOP/SPECIAL' => 'Contra College',
    'WCP-WORKSHOP/HAMBO' => 'Contra College',
    'FUM-WALTZ/CONTRA/WORKSHOP' => 'Contra College',
    'SRC-CAMP/CONTRA/SPECIAL' => 'Contra College',
    'SJW-ENGLISH/SPECIAL' => 'Playford Ball',
    'HVC-ENGLISH/SPECIAL' => 'Playford Ball',
    'HVC-ENGLISH' => 'Playford Ball',
    'ONLINE-ONLINE Meetup' => 'Online Meetup',
    'ONLINE-ONLINE Sound Workshop' => 'Online Workshop',
    'JG-CONTRA/CAMP/SPECIAL' => 'American Week',
    'JG-CAMP/CONTRA/COUPLE/MUSIC' => 'American Week',
    'LSC-CONTRA/SPECIAL' => 'American Week',
    'MEN-CAMP/CONTRA/COUPLE/MUSIC' => 'American Week',
    'LMDC-CONTRA/SPECIAL' => 'No Snow Ball',
    'OVMB-CONTRA/SPECIAL' => 'No Snow Ball',
    'ALM-CONTRA/SPECIAL' => 'No Snow Ball',
    'GOC-CONTRA/SPECIAL' => 'No Snow Ball',
    'MON-ENGLISH/CONTRA/SPECIAL/CAMP' => 'Spring Fever',
    'MON-CAMP/CONTRA/ENGLISH/MUSIC/SONG' => 'Spring Fling',
    'ALB-ENGLISH/MORRIS/SWORD/SPECIAL' => 'SKIP SERIES',
    'HC-ENGLISH/SPECIAL' => 'SKIP SERIES',
    'HVC-CONTRA/SPECIAL' => 'SKIP SERIES',
    'LSC-CONTRA/ENGLISH' => 'SKIP SERIES',
    'STALB-ENGLISH/CONCERT' => 'SKIP SERIES',
    'STALB-CONTRA/SPECIAL/CONCERT' => 'SKIP SERIES',
    'AMH-ENGLISH' => 'SKIP SERIES',
    'VAR-MORRIS/SPECIAL' => 'SKIP SERIES',
    'CCB-MORRIS/WORKSHOP/SPECIAL' => 'SKIP SERIES',
    'FUM-ENGLISH/CONTRA/SPECIAL' => 'SKIP SERIES',
    'FBH-ENGLISH/MUSIC/WORKSHOP' => 'SKIP SERIES',
    'GIC-SQUARE/SPECIAL' => 'SKIP SERIES',
    'ACC-ENGLISH/SPECIAL' => 'SKIP SERIES',
    'FUM-SPECIAL/ENGLISH/MOLLY/CONTRA' => 'SKIP SERIES',
    'BTW-CONTRA/SPECIAL/WORKSHOP' => 'SKIP SERIES',
    'TGH-CONTRA/SPECIAL/WORKSHOP' => 'SKIP SERIES',
    'LSC-ENGLISH/SPECIAL' => 'SKIP SERIES', # patsy bolt memorial 2011
    'ALB-ENGLISH/SPECIAL' => 'SKIP SERIES', # Chuck Warn lifetime achievement
);

my $dbh = $ENV{YES_DO_PROD}
    ? get_dbh(db => 'schedule', user => 'scheduler')
    : get_dbh(db => 'schedule_test', user => 'scheduler_test');

create_events($dbh);

sub create_events {
    my ($dbh) = @_;


    #my @old_events = bacds::Model::Event->load_all_from_old_schema(table => 'schedule2021_clean_for_migration');
    #my @old_events = bacds::Model::Event->load_all_from_really_old_schema(table => 'schedule2020');
    #my @old_events = bacds::Model::Event->load_all_from_really_old_schema(table => 'schedule2019');
    #my @old_events = bacds::Model::Event->load_all_from_really_old_schema(table => 'schedule2018');
    #my @old_events = bacds::Model::Event->load_all_from_really_old_schema(table => 'schedule2017');
    #my @old_events = bacds::Model::Event->load_all_from_really_old_schema(table => 'schedule2016');
    #my @old_events = bacds::Model::Event->load_all_from_really_old_schema(table => 'schedule2015');
    #my @old_events = bacds::Model::Event->load_all_from_really_old_schema(table => 'schedule2014');

    # need to be re-run on fried:
    my @old_events;
    #push @old_events, bacds::Model::Event->load_all_from_really_old_schema(table => 'schedule2013');
    # need to run this on fried: 
    # update events set name = 'Fall Ball' where event_id in (select event_id from events where series_id = (select series_id from series where name = 'Fall Ball'));
    # got ERROR 1093 (HY000): You can't specify target table 'events' for update in FROM clause
    # so ran this instead:
    # MariaDB [schedule]> update events set name = 'Fall Ball' where event_id in (1820, 1821, 2106, 2107, 2450, 2479, 2480, 2779, 2780);
    # insert into styles (name, created_ts) values ('COUPLE', current_timestamp());
    #push @old_events, bacds::Model::Event->load_all_from_really_old_schema(table => 'schedule2012');
    #push @old_events, bacds::Model::Event->load_all_from_really_old_schema(table => 'schedule2011');
    push @old_events, bacds::Model::Event->load_all_from_really_old_schema(table => 'schedule2010');

    foreach my $old (@old_events) {

        my $new = migrate_event($dbh, $old);

        attach_styles($dbh, $old, $new);

        attach_venues($dbh, $old, $new);

        attach_callers($dbh, $old, $new);

        attach_parent_org($dbh, $old, $new);
    }

}

sub migrate_event {
    my ($dbh, $old) = @_;

    my $new = $dbh->resultset('Event')->new({});


dump $old;

    if ($old->type eq 'BALANCE THE BAY SPECIAL CONTRA WEEKEND') {
        $new->name('Balance the Bay');
    } elsif ($old->type eq 'ENGLISH/CAMP' && $old->startday =~ /^20..-(10|11|12)-/) {
        $new->name('Fall Frolick');
    } elsif ($old->type eq 'ENGLISH/CAMP') {
        $new->name('Hey Days English Week');
    } elsif ($old->type eq 'FAMILY/CAMP') {
        $new->name('Family Camp');
    } elsif ($old->type eq 'ENGLISH/SPECIAL' && ($old->url//'') eq "/events/1718") {
        $new->name('1718 Ball');
    } elsif ($old->type eq 'ENGLISH/MORRIS/SWORD/SPECIAL') {
        $new->name('Michael Siemen Memorial');
    } elsif ($old->type eq 'CONTRA/SPECIAL' && $old->startday eq "2018-12-30") {
        $new->name('Zesty!');
    } elsif ($old->type eq 'CONTRA/ENGLISH' && $old->startday eq "2017-04-23") {
        $new->name('James Candlin Memorial');
    } elsif ($old->type eq 'ENGLISH/CONCERT' && $old->startday eq "2017-08-09") {
        $new->name('Phoenix In Concert');
    } elsif ($old->type eq 'CONTRA/SPECIAL/CONCERT' && $old->startday eq "2017-08-16") {
        $new->name('Mason & Weed In Concert');
    } elsif ($old->type eq 'ENGLISH/CONTRA/SPECIAL' && $old->startday eq "2015-09-10") {
        $new->name('Jody Dill Memorial');
    } elsif ($old->type eq 'SPECIAL/ENGLISH/MOLLY/CONTRA' && $old->startday eq "2013-03-09") {
        $new->name('Vanessa Schnatmeier Memorial');
    } elsif ($old->type eq 'ENGLISH/WORKSHOP/SPECIAL' && $old->startday eq "2011-06-08") {
        $new->name(q{Mary Luckhardt's 60th Birthday Celebration Dance & Potluck});
    } elsif ($old->type eq 'ENGLISH/SPECIAL' && $old->startday eq "2011-07-24") {
        $new->name(q{Patsy Bolt Memorial Celebration});
    } elsif ($old->type eq 'ALB-ENGLISH/SPECIAL' && $old->startday eq "2010-03-28") {
        $new->name(q{CDSS/BACDS ceremony celebrating Chuck Ward's 2009 CDSS Lifetime Contribution Award});
    }
    my $synthetic_name = join ' ', map { $old->$_ } qw/type loc leader/ ;
    $new->synthetic_name($new->name or $synthetic_name);
    say "doing event ".$new->synthetic_name;
    $new->start_date( $old->startday );
    $new->start_time( '23:59:59' );
    $new->end_date( $old->endday )
        if $old->endday;
    my $short_desc = $old->leader ? $old->leader.' with '.$old->band : $old->band;

    # We don't have a "comments" field in the new schema, but we're jamming
    # everything into the short_desc so just put it in there, with a marker
    # so we can find it later if we want. This was retrofitted onto the
    # migration halfway through after I noticed it wasn't handled.
    if ($old->comments) {
        # in cgi-bin/calendar.cgi the old data was printed in an <em> like this:
        # print td({-class => 'calcomment', -colspan => 4},em($cmts));
        #$short_desc .= ' <div style="calendar-event-comments>'.$old->comments.'</div>';
        # Oh, darn, in the fix-migrate-comments.pl I just ran for 2021-2014 I just stuck them in an <em>
        # OK I'll just continue with that.
        $short_desc .= ' <em>'.$old->comments.'</em>';
    }
    
    $short_desc =~ s/^ +//; #leading spaces in the data
    $new->short_desc( $short_desc );
    $new->is_series_defaults(0);

    my $key = join '-', $old->loc, $old->type;
    # craig hacking the db :-(
    if ($key =~ /ENGLISH&#8212;CANCELLED/) {
        $key = 'ASE-ENGLISH';
    }
    my $loc_str = $Series_Lookup{$key}
        or die "can't lookup series for '$key'";


    if ($loc_str eq 'Berkeley English') {
        my ($y, $m, $d) = split '-', $old->startday;
        my $date = DateTime->new(year => $y, month => $m, day => $d);
        if ($date->dow == 6) {
            $loc_str = 'Berkeley Fourth Saturday Experienced Dance';
        }
    }

    state $renames = {
        'Playford Ball' => 1,
        'American Week' => 1,
        'No Snow Ball' => 1,
        'Contra College' => 1,
        'Balance the Bay' => 1,
        'Family Week' => 1,
        'Fall Frolick' => 1,
        'Fall Ball' => 1,
        'Hey Days English Week' => 1,
        'Spring Fever' => 1,
        'Spring Fling' => 1,
    };
    if ($renames->{$loc_str}) {
        $new->name($loc_str);
    }
        

    if ($loc_str eq 'SKIP SERIES') {
        ;# no-op
    } else {
        my $rs;
        if ($key =~ /^ONLINE/) {
            $rs = $dbh->resultset('Series')->search({
                    name => $loc_str,
            }) or die "Series->search $loc_str% failed";
        } else {
            $rs = $dbh->resultset('Series')->search({
                    name => { -like => "$loc_str%" },
            }) or die "Series->search $loc_str% failed";
        }

        if (my $series_obj = $rs->next) {
            $new->series_id( $series_obj->series_id );
        } else {
            # ACC has no series ?
            warn "no series for $loc_str";
        }
    }

    $new->insert;

    return $new;
}


sub attach_styles {
    my ($dbh, $old, $new) = @_;

    my @old_styles;
    my $old_style = $old->type;
    if ($old_style =~ /ONLINE/) {
        push @old_styles, 'ONLINE' # fudging e.g. ONLINE Concert &amp; Dance
    } elsif ($old_style eq 'ENGLISH/CAMP') {
        push @old_styles, 'ENGLISH', 'CAMP';
    } elsif ($old_style eq 'ENGLISH/CAMP/SPECIAL/WEEKEND') {
        push @old_styles, 'ENGLISH', 'CAMP';
    } elsif ($old_style eq 'ENGLISH/WALTZ') {
        push @old_styles, 'ENGLISH', 'WALTZ';
    } elsif ($old_style eq 'ENGLISH/CONTRA') {
        push @old_styles, 'ENGLISH', 'CONTRA';
    } elsif ($old_style eq 'ENGLISH/DISPLAY/CRAFTS/CAMP/SPECIAL') {
        push @old_styles, 'ENGLISH', 'CAMP';
    } elsif ($old_style eq 'CAMP/FAMILY/ENGLISH/MUSIC/DISPLAY') {
        push @old_styles, 'ENGLISH', 'CAMP';
    } elsif ($old_style eq 'CAMP/ENGLISH/MUSIC/DISPLAY') {
        push @old_styles, 'ENGLISH', 'CAMP';
    } elsif ($old_style eq 'CONTRA/ENGLISH/DISPLAY/CRAFTS/CAMP/SPECIAL') {
        push @old_styles, 'CONTRA', 'ENGLISH', 'CAMP';
    } elsif ($old_style eq 'ENGLISH/SINGING/DISPLAY/CAMP') {
        push @old_styles, 'ENGLISH', 'CAMP';
    } elsif ($old_style eq 'SINGING/ENGLISH/WORKSHOP') {
        push @old_styles, 'SINGING', 'ENGLISH', 'WORKSHOP';
    } elsif ($old_style eq 'ENGLISH/WALTZ/WORKSHOP/SPECIAL') {
        push @old_styles, 'ENGLISH', 'WALTZ', 'WORKSHOP', 'SPECIAL';
    } elsif ($old_style eq 'WALTZ/WORKSHOP') {
        push @old_styles, 'WALTZ', 'WORKSHOP';
    } elsif ($old_style eq 'ENGLISH WORKSHOP') {
        push @old_styles, 'ENGLISH', 'WORKSHOP';
    } elsif ($old_style eq 'ENGLISH/WORKSHOP') {
        push @old_styles, 'ENGLISH', 'WORKSHOP';
    } elsif ($old_style eq 'ENGLISH/JAM') {
        push @old_styles, 'ENGLISH', 'JAM';
    } elsif ($old_style eq 'ENGLISH/COUPLE') {
        push @old_styles, 'ENGLISH', 'COUPLE';
    } elsif ($old_style eq 'CONTRA/JAM') {
        push @old_styles, 'CONTRA', 'JAM';
    } elsif ($old_style eq 'ENGLISH CAMP FALL FROLICK') {
        push @old_styles, 'ENGLISH', 'CAMP';
    } elsif ($old_style eq 'ENGLISH CAMP HEY DAYS') {
        push @old_styles, 'ENGLISH', 'CAMP';
    } elsif ($old_style eq 'CAMP/ENGLISH/MUSIC') {
        push @old_styles, 'ENGLISH', 'CAMP';
    } elsif ($old_style eq 'ENGLISH/MUSIC/WORKSHOP') {
        push @old_styles, 'ENGLISH', 'WORKSHOP';
    } elsif ($old_style eq 'ENGLISH/CAMP/SPECIAL') {
        push @old_styles, 'ENGLISH', 'CAMP', 'SPECIAL';
    } elsif ($old_style eq 'FAMILY/CAMP') {
        push @old_styles, 'FAMILY', 'CAMP';
    } elsif ($old_style eq 'CAMP/CONTRA/ENGLISH/IRISH/INTERNATIONAL/FAMILY/CRAFTS') {
        push @old_styles, 'FAMILY', 'CAMP';
    } elsif ($old_style eq 'CAMP/ENGLISH/CONTRA/SINGING/MUSIC') {
        push @old_styles, 'FAMILY', 'CAMP';
    } elsif ($old_style eq 'CAMP/CONTRA/ENGLISH/FAMILY/CRAFTS') {
        push @old_styles, 'FAMILY', 'CAMP';
    } elsif ($old_style eq 'CONTRA/CAMP') {
        push @old_styles, 'CONTRA', 'CAMP';
    } elsif ($old_style eq 'ENGLISH/REGENCY') {
        push @old_styles, 'ENGLISH', 'REGENCY';
    } elsif ($old_style eq 'ENGLISH/SPECIAL/WORKSHOP') {
        push @old_styles, 'ENGLISH', 'SPECIAL', 'WORKSHOP';
    } elsif ($old_style eq 'ENGLISH/WORKSHOP/SPECIAL') {
        push @old_styles, 'ENGLISH', 'WORKSHOP', 'SPECIAL';
    } elsif ($old_style eq 'ENGLISH/REGENCY/SPECIAL') {
        push @old_styles, 'ENGLISH', 'REGENCY', 'SPECIAL';
    } elsif ($old_style eq 'BALANCE THE BAY SPECIAL CONTRA WEEKEND') {
        push @old_styles, 'CONTRA', 'CAMP';
    } elsif ($old_style eq 'ENGLISH/SPECIAL') {
        push @old_styles, 'ENGLISH', 'SPECIAL';
    } elsif ($old_style eq 'CONTRA/SPECIAL') {
        push @old_styles, 'CONTRA', 'SPECIAL';
    } elsif ($old_style eq 'CONTRA/WALTZ/SPECIAL') {
        push @old_styles, 'CONTRA', 'WALTZ', 'SPECIAL';
    } elsif ($old_style eq 'WALTZ/CONTRA/WORKSHOP') {
        push @old_styles, 'WALTZ', 'CONTRA', 'WORKSHOP' ;
    } elsif ($old_style eq 'CONTRA/WALTZ') {
        push @old_styles, 'CONTRA', 'WALTZ';
    } elsif ($old_style eq 'CONTRA/ENGLISH') {
        push @old_styles, 'CONTRA', 'ENGLISH';
    } elsif ($old_style eq 'CONTRA/WORKSHOP/SPECIAL') {
        push @old_styles, 'CONTRA', 'WORKSHOP', 'SPECIAL';
    } elsif ($old_style eq 'CONTRA/WORKSHOP') {
        push @old_styles, 'CONTRA', 'WORKSHOP';
    } elsif ($old_style eq 'CONTRA/CAMP/SPECIAL') {
        push @old_styles, 'CONTRA', 'CAMP', 'SPECIAL';
    } elsif ($old_style eq 'CAMP/CONTRA/SPECIAL') {
        push @old_styles, 'CONTRA', 'CAMP', 'SPECIAL';
    } elsif ($old_style eq 'CAMP/CONTRA/COUPLE/MUSIC') {
        push @old_styles, 'CONTRA', 'CAMP';
    } elsif ($old_style eq 'FAMILY/CONTRA') {
        push @old_styles, 'FAMILY CONTRA';
    } elsif ($old_style eq 'CONTRA/FAMILY') {
        push @old_styles, 'FAMILY CONTRA';
    } elsif ($old_style eq 'FAMILY') {
        push @old_styles, 'FAMILY CONTRA';
    } elsif ($old_style eq 'CONTRAWORKSHOP') {
        push @old_styles, 'CONTRA', 'WORKSHOP';
    } elsif ($old_style eq 'ENGLISH/MORRIS/SWORD/SPECIAL') {
        push @old_styles, 'ENGLISH','MORRIS','SWORD','SPECIAL';
    } elsif ($old_style eq 'WORKSHOP/HAMBO') {
        push @old_styles, 'WORKSHOP','HAMBO';
    } elsif ($old_style eq 'CONTRAWORKSHOP/WALTZ') {
        push @old_styles, 'WORKSHOP','WALTZ';
    } elsif ($old_style eq 'ECDWORKSHOP/WALTZ') {
        push @old_styles, 'WORKSHOP','WALTZ';
    } elsif ($old_style eq 'ENGLISH/CONCERT') {
        push @old_styles, 'ENGLISH','CONCERT';
    } elsif ($old_style eq 'CONTRA/SPECIAL/CONCERT') {
        push @old_styles, 'CONTRA','CONCERT';
    } elsif ($old_style eq 'CONTRA/SPECIAL') {
        push @old_styles, 'CONTRA','SPECIAL';
    } elsif ($old_style eq 'ENGLISH/CONTRA/SPECIAL/CAMP') {
        push @old_styles, 'ENGLISH', 'CONTRA','SPECIAL', 'CAMP';
    } elsif ($old_style eq 'ENGLISH/CONTRA/SPECIAL') {
        push @old_styles, 'ENGLISH', 'CONTRA','SPECIAL';
    } elsif ($old_style eq 'SINGING/ENGLISH') {
        push @old_styles, 'SINGING', 'ENGLISH';
    } elsif ($old_style eq 'CONTRA/SPECIAL/WORKSHOP') {
        push @old_styles, 'CONTRA','SPECIAL', 'WORKSHOP';
    } elsif ($old_style eq 'MORRIS/SPECIAL') {
        push @old_styles, 'MORRIS', 'SPECIAL';
    } elsif ($old_style eq 'MORRIS/WORKSHOP/SPECIAL') {
        push @old_styles, 'MORRIS', 'WORKSHOP', 'SPECIAL';
    } elsif ($old_style eq 'ENGLISH/CEILIDH') {
        push @old_styles, 'ENGLISH', 'CEILIDH';
    } elsif ($old_style eq 'SQUARE/SPECIAL') {
        push @old_styles, 'SQUARE', 'SPECIAL';
    } elsif ($old_style eq 'BARN DANCE') {
        push @old_styles, 'BARN';
    } elsif ($old_style eq 'SPECIAL/ENGLISH/MOLLY/CONTRA') {
        push @old_styles, 'SPECIAL', 'ENGLISH', 'MOLLY', 'CONTRA';
    } elsif ($old_style eq 'CAMP/CONTRA/ENGLISH/MUSIC/SONG') {
        push @old_styles, 'SPECIAL', 'CAMP', 'ENGLISH', 'CONTRA';
    } else {
        push @old_styles, $old_style;
    }

    my $i = 1;

    # craig hacking the db :-(
    say "attaching styles @old_styles to ".$new->event_id;

    foreach my $style (@old_styles) {
        # craig hacking the db :-(
        if ($style =~ /ENGLISH&#8212;CANCELLED/) {
            say "skipping style for ".$new->name;
            return;
        }
        my $style = $dbh->resultset('Style')->search({
            name => $style,
        })->single
            or die "can't find $style in styles table";
        $new->add_to_styles($style, {
            ordering => $i++,
        });
    }
}

sub attach_venues {
    my ($dbh, $old, $new) = @_;

    my $vkey = $old->loc;

    my @rs = $dbh->resultset('Venue')->search({
        vkey => $vkey,
    });
    my $i = 1;
    @rs or die "can't find $vkey in venues table";
    $new->add_to_venues($rs[0], {
        ordering => $i++, # there is only 1
    });
}

sub attach_callers {
    my ($dbh, $old, $new) = @_;

    my $caller_name = $old->leader;
    $caller_name =~ s/^ +//;
    $caller_name =~ s/ +$//;

    # there's enough junk in the callers column that we might not be able to
    # suss out the caller, so just leave those blank and we can fill them in
    # manually later
    my @rs = $dbh->resultset('Caller')->search({
        name => $caller_name
    })
        or return;

    say "attaching caller $caller_name to event ".$new->event_id;
    $new->add_to_callers($rs[0], {
        ordering => 1, # there is only 1
    });
}

sub attach_parent_org {
    my ($dbh, $old, $new) = @_;

    my $org = 'BACDS';

    # just set them all up as BACDS for now
    my @rs = $dbh->resultset('ParentOrg')->search({
        abbreviation => $org,
    })
        or return;

    say "attaching org $org to event ".$new->event_id;
    $new->add_to_parent_orgs($rs[0], {
        ordering => 1, # there is only 1
    });
}
