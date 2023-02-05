=head1 NAME

bacds::Scheduler::Model::Calendar

=head1 SYNOPSIS

    my @events = $class->load_events_for_month('2022', '04');

=head1 DESCRIPTION

Mediates database access for cgi-bin/calendar2.pl

I'm only replacing that one function for now, which will be gated on
the DBIX_TEST cookie to start with, rather than rewriting the whole
thing.

=head1 METHODS

=cut

package bacds::Scheduler::Model::Calendar;

use 5.16.0;
use warnings;

use Carp;

use bacds::Scheduler::Util::Db qw/get_dbh/;

package OldEvent {
    use Class::Accessor::Lite (
        new => 1,
        rw => [ qw/startday endday type loc leader band comments is_canceled/ ]
    );
}

=head2 load_events_for_month

=cut

sub load_events_for_month {
    my ($class, $start_year, $start_month) = @_;

    my @events = _load_events($start_year, $start_month);

    my @res;
    foreach my $event (@events) {
        my $old = OldEvent->new({
            startday => $event->start_date->ymd,
            endday   => ($event->end_date ? $event->end_date->ymd : ''),
            type     => join('/', map $_->name, $event->styles->all),
            loc      => join('/', map $_->vkey, $event->venues->all),
            leader   => join(', ', map $_->name, $event->callers->all),
            band     => join(', ', map $_->name, $event->bands->all),
            comments => $event->short_desc, # maybe?
            is_canceled => $event->is_canceled,
        });
        push @res, $old;
    }
    return @res;
}

=head2 load_venue_list_for_month

=cut

sub load_venue_list_for_month {
    my ($class, $start_year, $start_month) = @_;

    # silly doing this a second time on the page, will fix someday
    my @events = _load_events($start_year, $start_month);

    my (%seen, @venue_list);
    foreach my $event (@events) {
        my $venue = $event->venues->first;
        next if $seen{$venue->vkey}++;
        # making a data structure from a | string is silly, but I'm
        # maintaining the old behavior
        push @venue_list, join '|',
            map { $venue->$_ } qw/
                vkey
                hall_name
                address
                city
            /;
            # 'comment' was the last item, but doesn't exist in the new schema
    }
    sort @venue_list

}

sub _load_events {
    my ($start_year, $start_month) = @_;

    croak "bad value for start_year in load_events_for_month: '$start_year'"
        unless $start_year =~ /^[0-9]{4}$/;
    croak "bad value for start_month in load_events_for_month: '$start_month'"
        unless $start_month =~ /^[0-9]{1,2}$/;

    my $dbh = get_dbh(debug => 0);

    my $date_param = sprintf "%04d-%02d-01", $start_year, $start_month;
    my $through_date = DateTime->last_day_of_month(
        year => $start_year,
        month => $start_month,
    )->ymd;

    my @events = $dbh->resultset('Event')->search({
        -or => [ start_date => { '>=', $date_param },
                 end_date   => { '>=', $date_param },
        ],
        start_date => { '<=', $through_date },
        is_deleted => 0,
    },{
        order_by => 'start_date',
    });

    return @events;
}


1;
