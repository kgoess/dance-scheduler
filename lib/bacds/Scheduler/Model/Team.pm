=head1 NAME

bacds::Scheduler::Model::Team - A performance team with associated styles.

=head1 SYNOPSIS

    my $team = $class->get_row($team_id);

=head1 DESCRIPTION

=head1 METHODS

=cut

package bacds::Scheduler::Model::Team;

use 5.16.0;
use warnings;

use parent 'bacds::Scheduler::Model';

sub get_model_name { 'Team' }
sub get_fields_for_output {
    qw/
        team_id
        name
        team_xid
        contact
        description
        sidebar
        team_url
        photo_url
        is_deleted
        created_ts
        modified_ts
    /
}
sub get_fields_for_input {
    qw/
        name
        team_xid
        parent_org_id
        contact
        description
        sidebar
        team_url
        photo_url
        is_deleted
    /
}
sub get_fkey_fields { qw/parent_org_id/ }
sub get_many_to_manys { 
    [qw/Style styles style_id/],
}
sub get_one_to_manys {
    [qw/ParentOrg parent_orgs parent_org_id parent_org/],
}
sub get_default_sorting { {-asc=>'name'} }

1;
