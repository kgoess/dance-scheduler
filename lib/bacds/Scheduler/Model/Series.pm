=head1 NAME

bacds::Scheduler::Model::Series - a regular series of events under one management

=head1 SYNOPSIS

    my $series = $class->get_row($series_id);

=head1 DESCRIPTION

=head1 METHODS

=cut

package bacds::Scheduler::Model::Series;

use 5.16.0;
use warnings;

use parent 'bacds::Scheduler::Model';

sub get_model_name { 'Series' }
sub get_fields_for_output {
    qw/
        created_ts
        default_start_time
        default_end_time
        default_parent_org_id
        default_style_id
        default_venue_id
        display_notes
        frequency
        is_deleted
        modified_ts
        name
        programmer_notes
        series_id
    /
}
sub get_fields_for_input {
    qw/
        name
        frequency
        default_venue_id
        default_parent_org_id
        default_parent_org_id
        default_start_time
        default_end_time
        display_notes
        programmer_notes
        is_deleted
    /
}
sub get_fkey_fields { }
sub get_many_to_manys { }
sub get_one_to_manys { }
sub get_default_sorting { {-asc=>'name'} }

1;
