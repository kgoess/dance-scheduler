use utf8;
package bacds::Scheduler::Schema::Result::ParentOrg;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

bacds::Scheduler::Schema::Result::ParentOrg

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

=head1 TABLE: C<parent_orgs>

=cut

__PACKAGE__->table("parent_orgs");

=head1 ACCESSORS

=head2 parent_org_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 full_name

  data_type: 'varchar'
  is_nullable: 1
  size: 191

=head2 abbreviation

  data_type: 'varchar'
  is_nullable: 1
  size: 191

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

=head2 url

  data_type: 'varchar'
  is_nullable: 1
  size: 255

=head2 photo_url

  data_type: 'varchar'
  is_nullable: 1
  size: 255

=cut

__PACKAGE__->add_columns(
  "parent_org_id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "full_name",
  { data_type => "varchar", is_nullable => 1, size => 191 },
  "abbreviation",
  { data_type => "varchar", is_nullable => 1, size => 191 },
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
  "url",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "photo_url",
  { data_type => "varchar", is_nullable => 1, size => 255 },
);

=head1 PRIMARY KEY

=over 4

=item * L</parent_org_id>

=back

=cut

__PACKAGE__->set_primary_key("parent_org_id");

=head1 UNIQUE CONSTRAINTS

=head2 C<abbreviation_idx>

=over 4

=item * L</abbreviation>

=back

=cut

__PACKAGE__->add_unique_constraint("abbreviation_idx", ["abbreviation"]);

=head2 C<parent_org_id_idx>

=over 4

=item * L</full_name>

=back

=cut

__PACKAGE__->add_unique_constraint("parent_org_id_idx", ["full_name"]);

=head1 RELATIONS

=head2 event_parent_orgs_maps

Type: has_many

Related object: L<bacds::Scheduler::Schema::Result::EventParentOrgsMap>

=cut

__PACKAGE__->has_many(
  "event_parent_orgs_maps",
  "bacds::Scheduler::Schema::Result::EventParentOrgsMap",
  { "foreign.parent_org_id" => "self.parent_org_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 teams

Type: has_many

Related object: L<bacds::Scheduler::Schema::Result::Team>

=cut

__PACKAGE__->has_many(
  "teams",
  "bacds::Scheduler::Schema::Result::Team",
  { "foreign.parent_org_id" => "self.parent_org_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07049 @ 2024-07-04 17:04:21
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:AW4XDdwtpTruKNNIcDVvoQ


use Role::Tiny::With;
with 'bacds::Scheduler::Schema::Role::AutoTimestamps';

__PACKAGE__->many_to_many(events => 'event_parent_orgs_maps', 'event');

sub get_fields_for_event_row {
    my ($self) = @_;
    return {
        name => $self->abbreviation,
        id   => $self->parent_org_id,
    };
}

sub get_fields_for_team_row {
    my ($self) = @_;
    return {
        name => $self->full_name,
        id   => $self->parent_org_id,
    };
}

1;
