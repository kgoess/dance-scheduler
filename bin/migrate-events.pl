#!/usr/bin/env perl

use 5.16.0;
use warnings;


use bacds::Model::Event;# the old CSV schema

use bacds::Scheduler::Util::Db qw/get_dbh/;

# this is a mapping of loc+type in the old schedule csv table
# to the new series table, by name
my %Series_Lookup = (
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
    'ONLINE-ONLINE Concert & Dance' => 'Online Concert',
    'SSU-ENGLISH/CAMP' => 'Hey Days English Week',
    'MON-FAMILY/CAMP' => 'Family Week',
    'JPC-CONTRA/CAMP' => 'Balance the Bay',
    'JPC-BALANCE THE BAY SPECIAL CONTRA WEEKEND' => 'Balance the Bay', # are these not the same thing?
    'SME-ENGLISH/REGENCY' => 'English Regency',
    'STM-ENGLISH/REGENCY' => 'English Regency',
    'ACC-ENGLISH' => 'Arlington Community Church English',
    'SPC-ENGLISH' => 'San Francisco English',
);

my $dbh = get_dbh();

create_events($dbh);

sub create_events {
    my ($dbh) = @_;


    my @old_events = bacds::Model::Event->load_all;

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

    my $name = join ' ', map { $old->$_ } qw/startday type loc leader/ ;

    say "doing $name";

    if ($old->type eq 'BALANCE THE BAY SPECIAL CONTRA WEEKEND') {
        $new->name('Balance the Bay');
    } elsif ($old->type eq 'ENGLISH/CAMP') {
        $new->name('Hey Days English Week');
    } elsif ($old->type eq 'FAMILY/CAMP') {
        $new->name('Family Camp');
    } else {
        # series don't really have a name in the old schema
        $new->name($name);
    }
    $new->start_time( $old->startday );
    $new->end_time( $old->endday )
        if $old->endday;
    $new->is_camp( $old->type ? 1 : 0 );
    $new->long_desc( $old->leader . ' with ' .$old->band );
    $new->short_desc( $old->leader );
    $new->is_template(0);

    my $key = join '-', $old->loc, $old->type;
    # craig hacking the db :-(
    if ($key =~ /ENGLISH&#8212;CANCELLED/) {
        $key = 'ASE-ENGLISH';
    }
    my $loc_str = $Series_Lookup{$key}
        or die "can't lookup series for '$key'";

    my $rs = $dbh->resultset('Series')->search({
            name => { -like => "$loc_str%" },
    }) or die "Series->search $loc_str% failed";

    if (my $series_obj = $rs->next) {
        $new->series_id( $series_obj->series_id );
    } else {
        # ACC has no series ?
        warn "no next for $loc_str";
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
    } elsif ($old_style eq 'FAMILY/CAMP') {
        push @old_styles, 'FAMILY', 'CAMP';
    } elsif ($old_style eq 'CONTRA/CAMP') {
        push @old_styles, 'CONTRA', 'CAMP';
    } elsif ($old_style eq 'ENGLISH/REGENCY') {
        push @old_styles, 'ENGLISH', 'REGENCY';
    } elsif ($old_style eq 'BALANCE THE BAY SPECIAL CONTRA WEEKEND') {
        push @old_styles, 'CONTRA', 'CAMP';
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
        my @rs = $dbh->resultset('Style')->search({
            name => $style,
        });
        @rs or die "can't find $style in styles table";
        $new->add_to_styles($rs[0], {
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
