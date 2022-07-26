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
            is_deleted => 0,
        },
        {
            name => 'San Francisco Contra',
            frequency => 'first and third Saturdays',
            is_deleted => 0,
        },
        {
            name => 'Palo Alto Contra',
            frequency => 'second, fourth and fifth Saturdays',
            is_deleted => 0,
        },
        {
            name => 'Palo Alto English',
            frequency => 'first, third, and fifth Fridays',
            is_deleted => 0,
        },
        {
            name => 'South Bay Contra',
            frequency => 'third Sunday afternoons, 3:00–6:00, lesson at 2:30',
            is_deleted => 0,
        },
        {
            name => 'Hayward Contra',
            frequency => 'fourth and fifth Sunday afternoons of each month, 4:00–7:00, lesson at 3:30',
            is_deleted => 0,
        },
        {
            name => 'Peninsula English (Palo Alto)',
            frequency => 'first, third, and fifth Tuesday evenings of each month (with a break from late June through Labor Day).',
            is_deleted => 0,
        },
        {
            name => 'Berkeley English',
            frequency => 'second and fourth Wednesday',
            is_deleted => 0,
        },
        {
            name => 'Berkeley Fourth Saturday Experienced Dance',
            frequency => 'fourth Saturday',
            is_deleted => 0,
        },
        {
            name => 'San Francisco English',
            frequency => 'second Saturday',
            is_deleted => 0,
        },
        {
            name => 'San Jose English',
            frequency => 'second Sunday afternoons of the month, September through June',
            is_deleted => 0,
        },
        {
            name => 'Atherton Woodshed',
            frequency => 'second Tuesday',
            is_deleted => 0,
        },
        {
            name => 'English Ceilidh',
            frequency => 'occasional',
            is_deleted => 0,
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
            is_deleted => 0,
        },
    );

    foreach my $series (@series) {
        my $new = $dbh->resultset('Series')->new({});

        say "doing series $series->{name}";

        $new->$_( $series->{$_} ) for qw/
            name
            frequency
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
