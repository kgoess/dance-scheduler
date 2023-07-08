package bacds::Scheduler::Model::ParentOrg;

use 5.16.0;
use warnings;

use parent 'bacds::Scheduler::Model';

sub get_model_name { 'ParentOrg' }
sub get_fields_for_output {
    qw/
        parent_org_id
        full_name
        url
        photo_url
        abbreviation
        created_ts
        modified_ts
        is_deleted
    /
}
sub get_fields_for_input {
    qw/
        full_name
        url
        photo_url
        abbreviation
        is_deleted
    /
}
sub get_fkey_fields { }
sub get_many_to_manys { }
sub get_one_to_manys { }
sub get_default_sorting { {-asc=>'abbreviation'} }

1;
