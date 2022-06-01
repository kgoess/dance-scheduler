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

use parent 'bacds::Scheduler::Model';

sub get_model_name { 'Series' }
sub get_other_table_names { }
sub get_fields_for_output {
    qw/
        series_id
        name
        frequency
        created_ts
        modified_ts
        is_deleted
    /
}
sub get_fields_for_input {
    qw/
        series_id
        name
        frequency
        is_deleted
    /
}
sub get_fkey_fields { }
sub get_relationships { }
sub get_one_to_manys { }
sub get_default_sorting { {-asc=>'name'} }

1;
