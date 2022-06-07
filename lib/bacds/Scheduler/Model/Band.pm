=head1 NAME

bacds::Scheduler::Model::Band - A group of talent with a collective name.

=head1 SYNOPSIS

    my $band = $class->get_row($band_id);

=head1 DESCRIPTION

=head1 METHODS

=cut

package bacds::Scheduler::Model::Band;

use 5.16.0;
use warnings;

use parent 'bacds::Scheduler::Model';

sub get_model_name { 'Band' }
sub get_other_table_names { qw/talents/ }
sub get_fields_for_output {
    qw/
        band_id
        name
        is_deleted
        created_ts
        modified_ts
    /
}
sub get_fields_for_input {
    qw/
        name
        is_deleted
    /
}
sub get_fkey_fields { }
sub get_relationships { 
    [qw/Talent talents talent_id/],
}
sub get_one_to_manys { }
sub get_default_sorting { {-asc=>'name'} }

1;
