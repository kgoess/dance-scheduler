=head1 NAME

bacds::Scheduler::Model::SeriesLister - fetch data for upcoming events in a series

=head1 SYNOPSIS

=head1 DESCRIPTION

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

 - series_path: e.g. /series/english/berkeley_wed/
 - series_id: e.g. 12345

=cut

sub get_upcoming_events_for_series {
    my ($class, %args) = @_;

    my $dbh = get_dbh(debug => 0);

    my $series;

    if (my $path = $args{series_path}) {
        # is this even a good idea? is fragile. should have an
        # index on series_url
        $path =~ s{^/}{};
        $path =~ s{/$}{};
        my $full_url = "https://bacds.org/$path/";
        $series = $dbh->resultset('Series')->find({
            is_deleted => 0,
            series_url => $full_url,
        }) or croak "get_upcoming_events_for_series can't ".
                    "find any series for $path -> $full_url";

    } elsif (my $series_id = $args{series_id}) {
        $series = $dbh->resultset('Series')->find({
            is_deleted => 0,
            series_id => $series_id,
        }) or die "can't find any series for series_id $series_id";
        
    } else {
        croak "missing required args series_path or series_id in call to get_upcoming_events_for_series";
    }

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

=cut 
sub get_event_details {
    my ($class, %args) = @_;

    my $event_id = $args{event_id}
        or croak "missing arg event_id in call to get_event_details";
}

1;
