=head1 NAME

bacds::Scheduler::Model::SeriesLister - fetch data for upcoming events in a series

=head1 SYNOPSIS

    $data = $c->get_upcoming_events_for_series(
        # one of these two:
        series_id => 123,
        series_xid => 'BERK-ENGLISH',
    );

=head1 DESCRIPTION

This is replacing the functions of the old serieslists.pl.

=head1 METHODS

=cut

package bacds::Scheduler::Model::SeriesLister;

use 5.16.0;
use warnings;

use Carp;
use Data::Dump qw/dump/;

use bacds::Scheduler::Util::Db qw/get_dbh/;
use bacds::Scheduler::Util::Time qw/get_now/;

=head2 get_upcoming_events_for_series

args can be either:

 - series_xid e.g. BERK-CONTRA
 - series_id: e.g. 12345

=cut

sub get_upcoming_events_for_series {
    my ($class, %args) = @_;

    croak "missing required args in call to get_upcoming_events_for_series, ".
          "need either series_id or series_xid "
        unless ($args{series_id} || $args{series_xid});

    my $dbh = get_dbh(debug => 0);

    my $series;

    my @search_arg =
        $args{series_xid}
        ? (series_xid => $args{series_xid})
        : (series_id => $args{series_id})
    ;

    $series = $dbh->resultset('Series')->find({
        is_deleted => 0,
        @search_arg,
    }) or croak "get_upcoming_events_for_series can't ".
                "find any series for @search_arg";

    my @events = $dbh->resultset('Event')->search({
        is_deleted => 0,
        series_id => $series->series_id,
        start_date => { '>=' => get_now()->ymd },
    });

    return {
        series => $series,
        events => \@events,
    }
}

=head2 get_event_details

Display the data for this one event.

Returns the same data structure as get_upcoming_events_for_series

=cut 

sub get_event_details {
    my ($class, %args) = @_;

    my $event_id = $args{event_id}
        or croak "missing arg event_id in call to get_event_details";

    my $dbh = get_dbh(debug => 0);

    my $event = $dbh->resultset('Event')->find({
        #ask for it explicitly and you can get it even if it's deleted
        #is_deleted => 0,
        event_id => $event_id,
    });

    return {
        series => $event->series,
        events => [$event],
    }
}

1;
