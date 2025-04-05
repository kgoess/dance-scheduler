package bacds::Scheduler::Model::Page;

use 5.16.0;
use warnings;

use parent 'bacds::Scheduler::Model';

sub get_model_name { 'Page' }
sub get_fields_for_output {
    qw/
        page_id
        title
        url_path
        short_desc
        body
        sidebar
        created_ts
        modified_ts
        is_deleted
    /
}
sub get_fields_for_input {
    qw/
        page_id
        title
        url_path
        short_desc
        body
        sidebar
        is_deleted
    /
}
sub get_fkey_fields { }
sub get_many_to_manys { }
sub get_one_to_manys { }
sub get_default_sorting { {-asc=>'title'} }

1;
