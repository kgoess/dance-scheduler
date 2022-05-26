=head1 NAME

bacds::Scheduler::Model::Venue - a venue is a event location

=head1 SYNOPSIS

    my $venue = $class->get_venue($venue_id);

=head1 DESCRIPTION

=head1 METHODS

=cut

package bacds::Scheduler::Model::Venue;

use 5.16.0;
use warnings;

use Dancer2;
use Data::Dump qw/dump/;
use DateTime;

use bacds::Scheduler::Schema;
use bacds::Scheduler::Util::Db qw/get_dbh/;

sub get_venues {
    my $dbh = get_dbh();

    # TODO by default don't load where is_deleted?
    # TODO maybe change that to is_active? or add is_active?

    my $resultset = $dbh->resultset('Venue')->search(
        # FIXME not working, returns nothing
        #{ is_deleted => false }
    );

    $resultset or die "empty set"; #TODO: More gracefully

    my @venues;

    while (my $venue = $resultset->next) {
        push @venues, venue_row_to_result($venue);
    }

    return \@venues;
};

sub get_venue {
    my ($self, $venue_id) = @_;

    my $dbh = get_dbh();

    my $venue = $dbh->resultset('Venue')->find($venue_id)
        or return false;

    return venue_row_to_result($venue);
}

sub post_venue {
    my ($self, $incoming_data) = @_;
    my $dbh = get_dbh();

    my $venue = $dbh->resultset('Venue')->new({});

    foreach my $column (qw/
        vkey
        hall_name
        address
        city
        zip
        comment
        is_deleted
        /){
        $venue->$column($incoming_data->{$column});
    };

    $venue->insert(); #TODO: check for failure
    #TODO: make it so that we are returning the new data from the db, instead of what was sent.
    return venue_row_to_result($venue);
};


sub put_venue {
    my ($self, $incoming_data) = @_;
    my $dbh = get_dbh();

    # FIXME I think there's a simpler syntax for this
    my $resultset = $dbh->resultset('Venue')->search(
        { venue_id=> { '=' => $incoming_data->{venue_id} } } # SQL::Abstract::Classic
    );

    $resultset or return 0; #TODO: More robust error handling
    my $venue = $resultset->next #it's searching on primary key, there will only be 0 or 1 result
        or return; # this is where lookup fails go

    foreach my $column (qw/
        vkey
        hall_name
        address
        city
        zip
        comment
        is_deleted
        /){
        $venue->$column($incoming_data->{$column});
    };

    $venue->update(); #TODO: check for failure
    
    return venue_row_to_result($venue);
}


sub venue_row_to_result {
    my ($venue) = @_;

    my $result = {};

    foreach my $field (qw/
        venue_id
        vkey
        hall_name
        address
        city
        zip
        comment
        is_deleted
        created_ts
        modified_ts
    /){
        $result->{$field} = $venue->$field;
    };


	# FIXME setting 'name' to match this in the javascript
	# but I think that's why update isn't working
    #    element.innerHTML = escapeHtml(row['name']);
    #    element.setAttribute('value', escapeHtml(row[name]));


    $result->{name} = $venue->vkey;

    foreach my $datetime (qw/created_ts modified_ts/){
        next unless $result->{$datetime};
        $result->{$datetime} = $result->{$datetime}->iso8601;
    };

    return $result;
}

true;
