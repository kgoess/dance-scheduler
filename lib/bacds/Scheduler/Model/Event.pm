package bacds::Scheduler::Model::Event;

use 5.16.0;
use warnings;

use parent 'bacds::Scheduler::Model';

sub get_model_name { 'Event' }
sub get_fields_for_output {
    qw/
        event_id
        name
        synthetic_name
        start_date
        start_time
        end_date
        end_time
        short_desc
        is_template
        created_ts
        modified_ts
        is_canceled
        is_deleted
    /
}
sub get_fields_for_input {
    qw/
        name
        synthetic_name
        start_date
        start_time
        end_date
        end_time
        short_desc
        is_template
        is_canceled
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
sub get_default_sorting { {-asc => [qw/start_date start_time/]} }

sub filter_input {
    my ($class, $field, $value) = @_;

    if ($field eq 'start_time' or $field eq 'end_time') {
        if (($value =~ tr/:/:/) == 1) { # change 7:30 to 7:30:00
            $value .= ':00';
        }
    }

    return $value;
}

1;
