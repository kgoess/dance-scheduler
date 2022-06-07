package bacds::Scheduler::Model::Style;

use 5.16.0;
use warnings;

use parent 'bacds::Scheduler::Model';

sub get_model_name { 'Style' }
sub get_other_table_names { }
sub get_fields_for_output {
    qw/
        style_id
        name
        created_ts
        modified_ts
        is_deleted
    /
}
sub get_fields_for_input {
    qw/
        name
        is_deleted
    /
}
sub get_fkey_fields { }
sub get_relationships { }
sub get_one_to_manys { }
sub get_default_sorting { {-asc=>'name'} }

1;
