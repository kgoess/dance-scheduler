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

#used by get_template_event
use bacds::Scheduler::Util::Db qw/get_dbh/;
use bacds::Scheduler::Model::Event;

use parent 'bacds::Scheduler::Model';

sub get_model_name { 'Series' }
sub get_fields_for_output {
    qw/
        created_ts
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
        display_notes
        frequency
        is_deleted
        name
        programmer_notes
    /
}
sub get_fkey_fields { }
sub get_many_to_manys { }
sub get_one_to_manys { }
sub get_default_sorting { {-asc=>'name'} }

=head3 get_template_event()

Looks for an event with is_template set to true and the provided
series_id

=cut

sub get_template_event {
    my ($class, $series_id) = @_;

    my $dbh = get_dbh();
    my $rs = $dbh->resultset('Event')->search({
        series_id => $series_id,
        is_template => 1,
    });
    my $row = $rs->single or return; #TODO: Actual error message
    my $event_id = $row->event_id;

    my $event_model = 'bacds::Scheduler::Model::Event';
    return $event_model->get_row($event_id);
}

1;
