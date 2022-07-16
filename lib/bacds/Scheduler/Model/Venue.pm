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

use parent 'bacds::Scheduler::Model';

sub get_model_name { 'Venue' }
sub get_fields_for_output {
    qw/
        venue_id
        vkey
        hall_name
        address
        city
        zip
        programmer_notes
        directions
        sidebar
        is_deleted
        created_ts
        modified_ts
    /
}
sub get_fields_for_input {
    qw/
        vkey
        hall_name
        address
        city
        zip
        programmer_notes
        directions
        sidebar
        is_deleted
    /
}
sub get_fkey_fields { }
sub get_many_to_manys { }
sub get_one_to_manys { }
sub get_default_sorting { {-asc=>'vkey'} }

1;
