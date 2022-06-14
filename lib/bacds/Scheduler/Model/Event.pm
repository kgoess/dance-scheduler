package bacds::Scheduler::Model::Event;

use 5.16.0;
use warnings;

use parent 'bacds::Scheduler::Model';

sub get_model_name { 'Event' }
sub get_fields_for_output {
    qw/
        event_id
        name
        start_time
        end_time
        is_camp
        long_desc
        short_desc
        is_template
        created_ts
        modified_ts
        is_deleted
    /
}
sub get_fields_for_input {
    qw/
        name
        start_time
        end_time
        is_camp
        long_desc
        short_desc
        is_template
        is_deleted
        series_id
    /
}

sub get_fkey_fields { qw/series_id/ }
sub get_many_to_manys { 
    [qw/Band bands band_id/],
    [qw/Caller callers caller_id/],
    [qw/ParentOrg parent_orgs parent_org_id/],
    [qw/Style styles style_id/],
    [qw/Talent talent talent_id/],
    [qw/Venue venues venue_id/],
}
sub get_one_to_manys { [qw/Series series series_id/] }
sub get_default_sorting { {-asc=>'start_time'} }

1;
