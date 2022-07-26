package bacds::Scheduler::Model::Talent;

use 5.16.0;
use warnings;

use parent 'bacds::Scheduler::Model';

sub get_model_name { 'Talent' }
sub get_fields_for_output {
    qw/
        talent_id
        name
        url
        photo_url
        created_ts
        modified_ts
        is_deleted
    /
}
sub get_fields_for_input {
    qw/
        name
        url
        photo_url
        is_deleted
    /
}
sub get_fkey_fields { }
sub get_many_to_manys { }
sub get_one_to_manys { }
sub get_default_sorting { {-asc=>'name'} }

1;
