=head1 NAME

bacds::Scheduler::Model::Series - a regular series of events under one management

=head1 SYNOPSIS

    my $series = $class->get_row($series_id);

=head1 DESCRIPTION

=head1 METHODS

=cut

package bacds::Scheduler::Model::Series;

use 5.32.1;
use feature 'signatures';
use warnings;
no warnings 'experimental::signatures';

use bacds::Scheduler::Util::Db qw/get_dbh/;
use bacds::Scheduler::Model::Event;

use parent 'bacds::Scheduler::Model';

sub get_model_name { 'Series' }
sub get_fields_for_output {
    qw/
        created_ts
        series_xid
        series_url
        photo_url
        display_text
        frequency
        is_deleted
        manager
        modified_ts
        name
        programmer_notes
        series_id
        short_desc
        sidebar
    /
}
sub get_fields_for_input {
    qw/
        display_text
        series_xid
        series_url
        photo_url
        frequency
        is_deleted
        manager
        name
        programmer_notes
        short_desc
        sidebar
    /
}
sub get_fkey_fields { }
sub get_many_to_manys { }
sub get_one_to_manys { }
sub get_default_sorting { {-asc=>'name'} }

=head3 get_series_defaults_event()

Looks for an event with is_series_defaults set to true and the provided
series_id

Returns false if nothing found.

=cut

sub get_series_defaults_event {
    my ($class, $series_id) = @_;

    my $dbh = get_dbh();
    my $rs = $dbh->resultset('Event')->search({
        series_id => $series_id,
        is_series_defaults => 1,
    });
    my $row = $rs->single or return;
    my $event_id = $row->event_id;

    my $event_model = 'bacds::Scheduler::Model::Event';
    return $event_model->get_row($event_id);
}

sub get_id_from_url_path ($class, $path) {
    my $dbh = get_dbh();
    my $rs = $dbh->resultset('Series')->find({
        series_url => $path,
        is_deleted => 0,
    }) or return;

    return $rs->series_id;
}

=head2 post_row

=cut

sub post_row ($class, $auditor, %incoming_data) {
    if ($incoming_data{series_url}) {
        sanitize_url(\$incoming_data{series_url});
    }

    $class->SUPER::post_row($auditor, %incoming_data);
}

=head2 put_row

=cut

sub put_row ($class, $auditor, %incoming_data) {
    if ($incoming_data{series_url}) {
        sanitize_url(\$incoming_data{series_url});
    }

    $class->SUPER::put_row($auditor, %incoming_data);
}

sub sanitize_url ($series_url_ref) {
    if ($$series_url_ref =~ m{ ^/ }x) {

        # no trailing slashes for our relative paths
        $$series_url_ref =~ s{ /$ }{}x;

        # let's enforce lowercase while we're at it
        $$series_url_ref = lc $$series_url_ref
    }
}

1;
