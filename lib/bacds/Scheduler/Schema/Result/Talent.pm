use utf8;
package bacds::Scheduler::Schema::Result::Talent;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

bacds::Scheduler::Schema::Result::Talent

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

=head1 TABLE: C<talent>

=cut

__PACKAGE__->table("talent");

=head1 ACCESSORS

=head2 talent_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 name

  data_type: 'varchar'
  is_nullable: 0
  size: 255

=head2 url

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

=cut

__PACKAGE__->add_columns(
  "talent_id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "name",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "url",
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
);

=head1 PRIMARY KEY

=over 4

=item * L</talent_id>

=back

=cut

__PACKAGE__->set_primary_key("talent_id");

=head1 UNIQUE CONSTRAINTS

=head2 C<talent_name_idx>

=over 4

=item * L</name>

=back

=cut

__PACKAGE__->add_unique_constraint("talent_name_idx", ["name"]);

=head1 RELATIONS

=head2 band_memberships

Type: has_many

Related object: L<bacds::Scheduler::Schema::Result::BandMembership>

=cut

__PACKAGE__->has_many(
  "band_memberships",
  "bacds::Scheduler::Schema::Result::BandMembership",
  { "foreign.talent_id" => "self.talent_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 event_talent_maps

Type: has_many

Related object: L<bacds::Scheduler::Schema::Result::EventTalentMap>

=cut

__PACKAGE__->has_many(
  "event_talent_maps",
  "bacds::Scheduler::Schema::Result::EventTalentMap",
  { "foreign.talent_id" => "self.talent_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07049 @ 2022-12-10 09:35:25
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:gzdJZdjCaC2vceDTPgWMCg

__PACKAGE__->many_to_many(bands=> 'band_memberships', 'band');

sub get_fields_for_band_row {
    my ($self) = @_;
    return {
        name => $self->name,
        id   => $self->talent_id,
    };
}

__PACKAGE__->many_to_many(events=> 'event_talent_maps', 'event');

sub get_fields_for_event_row {
    my ($self) = @_;
    return {
        name => $self->name,
        id   => $self->talent_id,
    };
}

use Role::Tiny::With;
with 'bacds::Scheduler::Schema::Role::AutoTimestamps';
1;
