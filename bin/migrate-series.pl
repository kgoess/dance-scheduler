#!/usr/bin/env perl

use 5.16.0;
use warnings;

use bacds::Scheduler::Util::Db qw/get_dbh/;

my $dbh = get_dbh();

create_series($dbh);

sub create_series {
    my ($dbh) = @_;

    # from this list here:
    # https://bacds.org/series/
    # and from the currently db of events
    my @series = (
        {
            name => 'Berkeley Contra',
            frequency => 'first, third and fifth Wednesdays',
            style => 'CONTRA',
            venue => 'CCB',
            parent => 'BACDS',
            is_deleted => 0,
        },
        {
            name => 'San Francisco Contra',
            frequency => 'first and third Saturdays',
            style => 'CONTRA',
            venue => 'SF',
            parent => 'BACDS',
            is_deleted => 0,
        },
        {
            name => 'Palo Alto Contra',
            frequency => 'second, fourth and fifth Saturdays',
            style => 'CONTRA',
            venue => 'FUM',
            parent => 'BACDS',
            is_deleted => 0,
        },
        {
            name => 'South Bay Contra',
            frequency => 'third Sunday afternoons, 3:00–6:00, lesson at 2:30',
            style => 'CONTRA',
            venue => 'FSJ',
            parent => 'BACDS',
            is_deleted => 0,
        },
        {
            name => 'Hayward Contra',
            frequency => 'fourth and fifth Sunday afternoons of each month, 4:00–7:00, lesson at 3:30',
            style => 'CONTRA',
            venue => 'HVC',
            parent => 'BACDS',
            is_deleted => 0,
        },
        {
            name => 'Peninsula English (Palo Alto)',
            frequency => 'first, third, and fifth Tuesday evenings of each month (with a break from late June through Labor Day).',
            style => 'ENGLISH',
            venue => 'ASE',
            parent => 'BACDS',
            is_deleted => 0,
        },
        {
            name => 'Berkeley English',
            frequency => 'second and fourth Wednesday',
            style => 'ENGLISH',
            venue => 'CCB',
            parent => 'BACDS',
            is_deleted => 0,
        },
        {
            name => 'Berkeley Fourth Saturday Experienced Dance',
            frequency => 'fourth Saturday',
            style => 'ENGLISH',
            venue => 'CCB',
            parent => 'BACDS',
            is_deleted => 0,
        },
        {
            name => 'San Francisco English',
            frequency => 'second Saturday',
            style => 'ENGLISH',
            venue => 'SJP',
            parent => 'BACDS',
            is_deleted => 0,
        },
        {
            name => 'San Jose English',
            frequency => 'second Sunday afternoons of the month, September through June',
            style => 'ENGLISH',
            venue => 'FUM',
            parent => 'BACDS',
            is_deleted => 0,
        },
        {
            name => 'Atherton Woodshed',
            frequency => 'second Tuesday',
            style => 'ENGLISH',
            venue => 'HPP',
            parent => 'BACDS',
            is_deleted => 0,
        },
        {
            name => 'English Ceilidh',
            frequency => 'occasional',
            style => 'CEILIDH',
            # venue => 'CCB',
            parent => 'BACDS',
            is_deleted => 0,
        },
        {
            name => 'Odd Sundays Online',
            frequency => 'odd-numbered Sundays',
            style => 'ENGLISH',
            venue => 'ONLINE',
            parent => 'BACDS',
            is_deleted => 0,
        },
        {
            name => 'Online Concerts',
            frequency => 'occasional',
            style => 'CONCERT',
            # venue => 'CCB',
            parent => 'BACDS',
            is_deleted => 0,
        },
        {
            name => 'Hey Days English Week',
            frequency => 'annual',
            style => 'ENGLISH',
            venue => 'SSU',
            parent => 'BACDS',
            is_deleted => 0,
        },
        {
            name => 'Family Week',
            frequency => 'annual',
            style => 'ENGLISH',
            venue => 'MON',
            parent => 'BACDS',
            is_deleted => 0,
        },
        {
            name => 'Balance the Bay',
            frequency => 'annual',
            style => 'CONTRA',
            venue => 'PRC',
            parent => 'BACDS',
            is_deleted => 0,
        },
        {
            name => 'English Regency',
            frequency => 'second Fridays',
            style => 'REGENCY',
            venue => 'STM',
            parent => 'BACDS',
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

        my $style_id = get_style_id($series->{style});
        $new->default_style_id($style_id);

        my $venue_id = get_venue_id($series->{venue});
        $new->default_venue_id($venue_id);

        my $parent_org_id = get_parent_org_id($series->{parent});
        $new->default_parent_org_id($parent_org_id);

        $new->insert;

    }
}

sub get_style_id {
    my ($style) = @_;

    my @rs = $dbh->resultset('Style')->search({
        name => $style,
    });
    @rs or die "can't find $style in styles table";

    return $rs[0]->style_id;
}

sub get_venue_id {
    my ($venue) = @_;

    return unless $venue;

    my @rs = $dbh->resultset('Venue')->search({
        vkey => $venue,
    });
    @rs or die "can't find $venue in venues table";

    return $rs[0]->venue_id;
}

sub get_parent_org_id {
    my ($parent_org) = @_;

    my @rs = $dbh->resultset('ParentOrg')->search({
        abbreviation => $parent_org,
    });
    @rs or die "can't find $parent_org in parent_orgs table";

    return $rs[0]->parent_org_id;
}
