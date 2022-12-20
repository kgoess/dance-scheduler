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
        rw => [ qw/startday endday type loc leader band comments/ ]
    );
}

sub load_events_for_month {
    my ($class, $start_year, $start_month) = @_;

    my $dbh = get_dbh(debug => 0);

    croak "bad value for start_year in load_events_for_month: '$start_year'"
        unless $start_year =~ /^[0-9]{4}$/;
    croak "bad value for start_month in load_events_for_month: '$start_month'"
        unless $start_month =~ /^[0-9]{1,2}$/;

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
        });
        push @res, $old;
    }
    return @res;
}

1;
