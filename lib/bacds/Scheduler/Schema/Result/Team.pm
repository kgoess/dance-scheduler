use utf8;
package bacds::Scheduler::Schema::Result::Team;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

bacds::Scheduler::Schema::Result::Team

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 COMPONENTS LOADED

=over 4

=item * L<DBIx::Class::InflateColumn::DateTime>

=back

=cut

__PACKAGE__->load_components("InflateColumn::DateTime");

=head1 TABLE: C<teams>

=cut

__PACKAGE__->table("teams");

=head1 ACCESSORS

=head2 team_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 name

  data_type: 'varchar'
  is_nullable: 1
  size: 191

=head2 team_xid

  data_type: 'char'
  is_nullable: 0
  size: 24

=head2 contact

  data_type: 'varchar'
  is_nullable: 1
  size: 2048

=head2 description

  data_type: 'longtext'
  is_nullable: 1

=head2 sidebar

  data_type: 'longtext'
  is_nullable: 1

=head2 team_url

  data_type: 'varchar'
  is_nullable: 1
  size: 255

=head2 photo_url

  data_type: 'varchar'
  is_nullable: 1
  size: 255

=head2 is_deleted

  data_type: 'tinyint'
  default_value: 0
  is_nullable: 0

=head2 created_ts

  data_type: 'datetime'
  datetime_undef_if_invalid: 1
  is_nullable: 0

=head2 modified_ts

  data_type: 'timestamp'
  datetime_undef_if_invalid: 1
  default_value: current_timestamp
  is_nullable: 0

=head2 parent_org_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "team_id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "name",
  { data_type => "varchar", is_nullable => 1, size => 191 },
  "team_xid",
  { data_type => "char", is_nullable => 0, size => 24 },
  "contact",
  { data_type => "varchar", is_nullable => 1, size => 2048 },
  "description",
  { data_type => "longtext", is_nullable => 1 },
  "sidebar",
  { data_type => "longtext", is_nullable => 1 },
  "team_url",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "photo_url",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "is_deleted",
  { data_type => "tinyint", default_value => 0, is_nullable => 0 },
  "created_ts",
  {
    data_type => "datetime",
    datetime_undef_if_invalid => 1,
    is_nullable => 0,
  },
  "modified_ts",
  {
    data_type => "timestamp",
    datetime_undef_if_invalid => 1,
    default_value => \"current_timestamp",
    is_nullable => 0,
  },
  "parent_org_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</team_id>

=back

=cut

__PACKAGE__->set_primary_key("team_id");

=head1 UNIQUE CONSTRAINTS

=head2 C<team_name_idx>

=over 4

=item * L</name>

=back

=cut

__PACKAGE__->add_unique_constraint("team_name_idx", ["name"]);

=head2 C<team_xid_idx>

=over 4

=item * L</team_xid>

=back

=cut

__PACKAGE__->add_unique_constraint("team_xid_idx", ["team_xid"]);

=head1 RELATIONS

=head2 event_team_maps

Type: has_many

Related object: L<bacds::Scheduler::Schema::Result::EventTeamMap>

=cut

__PACKAGE__->has_many(
  "event_team_maps",
  "bacds::Scheduler::Schema::Result::EventTeamMap",
  { "foreign.team_id" => "self.team_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 parent_org

Type: belongs_to

Related object: L<bacds::Scheduler::Schema::Result::ParentOrg>

=cut

__PACKAGE__->belongs_to(
  "parent_org",
  "bacds::Scheduler::Schema::Result::ParentOrg",
  { parent_org_id => "parent_org_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "RESTRICT",
    on_update     => "RESTRICT",
  },
);

=head2 programmer_teams_maps

Type: has_many

Related object: L<bacds::Scheduler::Schema::Result::ProgrammerTeamsMap>

=cut

__PACKAGE__->has_many(
  "programmer_teams_maps",
  "bacds::Scheduler::Schema::Result::ProgrammerTeamsMap",
  { "foreign.team_id" => "self.team_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 team_styles_maps

Type: has_many

Related object: L<bacds::Scheduler::Schema::Result::TeamStylesMap>

=cut

__PACKAGE__->has_many(
  "team_styles_maps",
  "bacds::Scheduler::Schema::Result::TeamStylesMap",
  { "foreign.team_id" => "self.team_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07049 @ 2024-07-04 17:04:21
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:tUdP9ODbF4daPFrMJ3uwTg

__PACKAGE__->many_to_many(styles => 'team_styles_maps', 'style');
__PACKAGE__->many_to_many(events=> 'event_team_maps', 'event');

sub get_fields_for_event_row {
    my ($self) = @_;
    return {
        name => $self->name,
        id   => $self->team_id,
    };
}

sub get_fields_for_programmer_row {
    my ($self) = @_;
    return {
        name => $self->name,
        id   => $self->team_id,
    };
}

use Role::Tiny::With;
with 'bacds::Scheduler::Schema::Role::AutoTimestamps';
1;
