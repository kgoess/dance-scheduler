=head1 NAME

bacds::Scheduler::Model::Series - a regular series of events under one management

=head1 SYNOPSIS

    my $series = $class->get_series($series_id);

=head1 DESCRIPTION

=head1 METHODS

=cut

package bacds::Scheduler::Model::Series;

use 5.16.0;
use warnings;

use Dancer2;
use Data::Dump qw/dump/;
use DateTime;

use bacds::Scheduler::Schema;
use bacds::Scheduler::Util::Db qw/get_dbh/;

sub get_seriess {
    my $dbh = get_dbh();

    # TODO by default don't load where is_deleted?
    # TODO maybe change that to is_active? or add is_active?

    my $resultset = $dbh->resultset('Series')->search(
        # FIXME not working, returns nothing
        #{ is_deleted => false }
    );

    $resultset or die "empty set"; #TODO: More gracefully

    my @seriess;

    while (my $series = $resultset->next) {
        push @seriess, series_row_to_result($series);
    }

    return \@seriess;
};

sub get_series {
    my ($self, $series_id) = @_;

    my $dbh = get_dbh();

    my $series = $dbh->resultset('Series')->find($series_id)
        or return false;

    return series_row_to_result($series);
}

sub post_series {
    my ($self, $incoming_data) = @_;
    my $dbh = get_dbh();

    my $series = $dbh->resultset('Series')->new({});

    foreach my $column (qw/
        name
        frequency
        is_deleted
        /){
        $series->$column($incoming_data->{$column});
    };

    $series->insert(); #TODO: check for failure
    #TODO: make it so that we are returning the new data from the db, instead of what was sent.
    return series_row_to_result($series);
};


sub put_series {
    my ($self, $incoming_data) = @_;
    my $dbh = get_dbh();

    # FIXME I think there's a simpler syntax for this
    my $resultset = $dbh->resultset('Series')->search(
        { series_id=> { '=' => $incoming_data->{series_id} } } # SQL::Abstract::Classic
    );

    $resultset or return 0; #TODO: More robust error handling
    my $series = $resultset->next #it's searching on primary key, there will only be 0 or 1 result
        or return; # this is where lookup fails go

    foreach my $column (qw/
        name
        frequency
        is_deleted
        /){
        $series->$column($incoming_data->{$column});
    };

    $series->update(); #TODO: check for failure
    
    return series_row_to_result($series);
}


sub series_row_to_result {
    my ($series) = @_;

    my $result = {};

    foreach my $field (qw/
        series_id
        name
        frequency
        is_deleted
        created_ts
        modified_ts
    /){
        $result->{$field} = $series->$field;
    };

    foreach my $datetime (qw/created_ts modified_ts/){
        next unless $result->{$datetime};
        $result->{$datetime} = $result->{$datetime}->iso8601;
    };

    return $result;
}

true;
