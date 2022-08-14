#!/usr/bin/env perl

use 5.16.0;
use warnings;

use bacds::Scheduler::Util::Db qw/get_dbh/;

my $dbh = get_dbh();

create_series($dbh);
setup_event_templates($dbh);

sub create_series {
    my ($dbh) = @_;

    # from this list here:
    # https://bacds.org/series/
    # and from the currently db of events
    my @series = (
        {
            name => 'Berkeley Contra',
            frequency => 'first, third and fifth Wednesdays',
            series_url => 'https://bacds.org/series/contra/berkeley_wed/',
            is_deleted => 0,
            sidebar => <<'EOL', # ./contra/berkeley_wed/content.html:
<!--#include virtual="/series/shared/role_name_lr.html" -->
<!--#include virtual="/series/shared/location_gnc.html" -->
<!--#include virtual="/series/shared/time_late_150.html" -->
<!--#include virtual="/series/shared/price_weeknight.html" -->
<!--#include virtual="/series/shared/directions_gnc.html" -->
EOL
        },
        {
            name => 'San Francisco Contra',
            frequency => 'first and third Saturdays',
            series_url => 'https://bacds.org/series/contra/san_francisco/',
            is_deleted => 0,
        },
        {
            name => 'Palo Alto Contra',
            frequency => 'second, fourth and fifth Saturdays',
            series_url => 'https://bacds.org/series/contra/palo_alto/',
            is_deleted => 0,
            sidebar => <<'EOL', # ./contra/palo_alto/content.html:
<!--#include virtual="/series/shared/role_name_lr.html" -->
<!--#include virtual="/series/shared/location_pa.html" -->
<!--#include virtual="/series/shared/time_late_lesson_180.html" -->
<!--#include virtual="/series/shared/price_weekend.html" -->
<!--#include virtual="/series/shared/directions_pa.html" -->
EOL
        },
        {
            name => 'Palo Alto English',
            frequency => 'first, third, and fifth Fridays',
            series_url => 'https://bacds.org/series/english/peninsula/',
            is_deleted => 0,
            sidebar => <<'EOL', # ./english/peninsula/content.html:
<!--#include virtual="/series/shared/location_ast.html" -->
<!--#include virtual="/series/shared/time_mid_120.html" -->
<!--#include virtual="/series/shared/price_standard.html" -->
<!--#include virtual="/series/shared/directions_jls.html" -->
<!--#include virtual="/series/shared/directions_ast.html" -->
EOL
        },
        {
            name => 'South Bay Contra',
            frequency => 'third Sunday afternoons, 3:00–6:00, lesson at 2:30',
            series_url => 'https://bacds.org/series/contra/san_jose/',
            is_deleted => 0,
            sidebar => <<'EOL', # ./contra/san_jose/content.html:
<!--#include virtual="/series/shared/location_fsj.html" -->
<!--#include virtual="/series/shared/time_aft_180_3.html" -->
<!--#include virtual="/series/shared/price_weekend_sbc.html" -->
<!--#include virtual="/series/shared/directions_fsj.html" -->
EOL
        },
        {
            name => 'Hayward Contra',
            frequency => 'fourth and fifth Sunday afternoons of each month, 4:00–7:00, lesson at 3:30',
            is_deleted => 0,
            sidebar => <<'EOL', # ./english/hayward/content.html:
<!--#include virtual="/series/shared/location_hayward.html" -->
<!--#include virtual="/series/shared/time_aft_180_4.html" -->
EOL
        },
        {
            name => 'Peninsula English (Palo Alto)',
            frequency => 'first, third, and fifth Tuesday evenings of each month (with a break from late June through Labor Day).',
            series_url => 'https://bacds.org/series/english/palo_alto/',
            is_deleted => 0,
            sidebar => <<'EOL', # ./english/palo_alto/content.html:
<!--#include virtual="/series/shared/location_mt.html" -->
<!--#include virtual="/series/shared/time_late_lesson_150.html" -->
<!--#include virtual="/series/shared/price_weekend.html" -->
<!--#include virtual="/series/shared/directions_mt.html" -->
EOL
        },
        {
            name => 'Berkeley English',
            frequency => 'second and fourth Wednesday',
            series_url => 'https://bacds.org/series/english/berkeley_wed/',
            is_deleted => 0,
            sidebar => <<'EOL', # ./english/berkeley_wed/content.html:
<!--#include virtual="/series/shared/time_special_bwe.html" -->
<!--#include virtual="/series/shared/location_gnc.html" -->
<!--#include virtual="/series/shared/price_weeknight.html" -->
<!--#include virtual="/series/shared/directions_gnc.html" -->
EOL
        },
        {
            name => 'Berkeley Fourth Saturday Experienced Dance',
            frequency => 'fourth Saturday',
            series_url => 'https://bacds.org/series/english/berkeley_sat/',
            is_deleted => 0,
            sidebar => <<'EOL', # ./english/berkeley_sat/content.html:
<!--#include virtual="/series/shared/location_gnc.html" -->
<!--#include virtual="/series/shared/time_mid_150.html" -->
<!--#include virtual="/series/shared/price_weekend.html" -->
<!--#include virtual="/series/shared/directions_gnc.html" -->
EOL
        },
        {
            name => 'San Francisco English',
            frequency => 'second Saturday',
            series_url => 'https://bacds.org/series/english/san_francisco/',
            is_deleted => 0,
            sidebar => <<'EOL', # ./english/san_francisco/content.html:
<!--#include virtual="/series/shared/location_spc.html" -->
<!--#include virtual="/series/shared/time_special_spc.html" -->
<!--#include virtual="/series/shared/price_weekend.html" -->
<!--#include virtual="/series/shared/directions_spc.html" -->
EOL
        },
        {
            name => 'San Jose English',
            frequency => 'second Sunday afternoons of the month, September through June',
            series_url => 'https://bacds.org/series/english/san_jose/',
            is_deleted => 0,
            sidebar => <<'EOL', # ./english/san_jose/content.html:
<!--#include virtual="/series/shared/location_fsj.html" -->
<!--#include virtual="/series/shared/time_aft_150_3.html" -->
<!--#include virtual="/series/shared/price_weekend.html" -->
<!--#include virtual="/series/shared/directions_fsj.html" -->
EOL
        },
        {
            name => 'Atherton Woodshed',
            frequency => 'second Tuesday',
            is_deleted => 0,
            sidebar => <<'EOL', # ./woodshed/atherton/content.html:
<!--#include virtual="/series/shared/location_hpp.html" -->
<!--#include virtual="/series/shared/time_late_120.html" -->
<!--#include virtual="/series/shared/price_woodshed.html" -->
<!--#include virtual="/series/shared/directions_hpp.html" -->
EOL
        },
        {
            name => 'English Ceilidh',
            frequency => 'occasional',
            is_deleted => 0,
            sidebar => <<'EOL', # ./ceilidh/oakland/content.html:
<!--#include virtual="/series/shared/location_hum.html" -->
<!--#include virtual="/series/shared/time_mid.html" -->
<!--#include virtual="/series/shared/price_weekend.html" -->
<!--#include virtual="/series/shared/directions_hum.html" -->
EOL
        },
        {
            name => 'Odd Sundays Online',
            frequency => 'odd-numbered Sundays',
            is_deleted => 0,
        },
        {
            name => 'Online Concerts',
            frequency => 'occasional',
            is_deleted => 0,
        },
        {
            name => 'Hey Days English Week',
            frequency => 'annual',
            is_deleted => 0,
        },
        {
            name => 'Family Week',
            frequency => 'annual',
            is_deleted => 0,
        },
        {
            name => 'Balance the Bay',
            frequency => 'annual',
            is_deleted => 0,
        },
        {
            name => 'English Regency',
            frequency => 'second Fridays',
            series_url => 'https://bacds.org/series/english/palo_alto_reg/',
            is_deleted => 0,
        },
    );

    foreach my $series (@series) {
        my $new = $dbh->resultset('Series')->new({});

        say "doing series $series->{name}";

        $new->$_( $series->{$_} ) for qw/
            name
            frequency
            series_url
            sidebar
        /;
        $new->is_deleted(0);

        $new->insert;
    }
}


sub setup_event_templates {
    my ($dbh) = @_;

    my @templates = (
        {
            series_name => "Berkeley Contra",
            start_time =>'19:30',
            style =>  'CONTRA',
            venue =>  'CCB',
            parent_org => 'BACDS',
            is_template => 1,
        },
        {
            series_name => "Berkeley English",
            start_time =>'19:30',
            style =>  'ENGLISH',
            venue =>  'CCB',
            parent_org => 'BACDS',
            is_template => 1,
        },
        {
            series_name => "Berkeley Fourth Saturday Experienced Dance",
            start_time =>'19:30',
            style =>  'ENGLISH',
            venue =>  'CCB',
            parent_org => 'BACDS',
            is_template => 1,
        },
        {
            series_name => "San Francisco English",
            start_time =>'19:30',
            style =>  'ENGLISH',
            venue =>  'SJP',
            parent_org => 'BACDS',
            is_template => 1,
        },
    );

    foreach my $template (@templates) {

        my $event = $dbh->resultset('Event')->new({});
        $event->is_deleted(0);
        $event->is_template(1);
        $event->start_time($template->{start_time});
        $event->insert;

        my $rs;

        $rs = $dbh->resultset('Series')->search({
            name => $template->{series_name}
        });
        my $series = $rs->single or die "can't find series for $template->{series_name}";
        $event->series_id($series->id);
        $event->update;

        $rs = $dbh->resultset('Style')->search({
            name => $template->{style}
        });
        my $style = $rs->single or die "can't find style for $template->{style}";
        $event->add_to_styles($style, {
            ordering => 1,
        });

        $rs = $dbh->resultset('Venue')->search({
            vkey => $template->{venue}
        });
        my $venue = $rs->single or die "can't find venue for $template->{venue}";
        $event->add_to_venues($venue, {
            ordering => 1,
        });

        $rs = $dbh->resultset('ParentOrg')->search({
           abbreviation  => $template->{parent_org}
        });
        my $parent_org = $rs->single or die "can't find parent_org for $template->{parent_org}";
        $event->add_to_parent_orgs($parent_org, {
            ordering => 1,
        });
    }
}
