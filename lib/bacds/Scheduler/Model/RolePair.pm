package bacds::Scheduler::Model::RolePair;

use 5.16.0;
use warnings;

use parent 'bacds::Scheduler::Model';

sub get_model_name { 'RolePair' }
sub get_fields_for_output {
    qw/
        role_pair_id
        role_pair
        created_ts
        modified_ts
        is_deleted
    /
}
sub get_fields_for_input {
    qw/
        role_pair
        is_deleted
    /
}
sub get_fkey_fields { }
sub get_many_to_manys { }
sub get_one_to_manys { }
sub get_default_sorting { {-asc=>'role_pair'} }

1;
