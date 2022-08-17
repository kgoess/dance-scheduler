=head1 NAME

bacds::Scheduler::Model::Programmer - A person with login information who has permission to edit dances.

=head1 SYNOPSIS

    my $programmer = $class->get_row($programmer_id);

=head1 DESCRIPTION

=head1 METHODS

=cut

package bacds::Scheduler::Model::Programmer;

use 5.16.0;
use warnings;

use parent 'bacds::Scheduler::Model';

sub get_model_name { 'Programmer' }
sub get_fields_for_output {
    qw/
        programmer_id
        name
        email
        is_superuser
        is_deleted
        created_ts
        modified_ts
    /
}
sub get_fields_for_input {
    qw/
        email
        name
        is_superuser
        is_deleted
    /
}
sub get_fkey_fields { }
sub get_many_to_manys { 
    [qw/Series series series_id/],
    [qw/Event events event_id/],
}
sub get_one_to_manys { }
sub get_default_sorting { {-asc=>'email'} }

1;
