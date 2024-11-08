use utf8;
package bacds::Scheduler::Schema::Result::EventRolePairsMap;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

bacds::Scheduler::Schema::Result::EventRolePairsMap

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

=head1 TABLE: C<event_role_pairs_map>

=cut

__PACKAGE__->table("event_role_pairs_map");

=head1 ACCESSORS

=head2 event_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 role_pair_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 ordering

  data_type: 'integer'
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
  "event_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "role_pair_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "ordering",
  { data_type => "integer", is_nullable => 0 },
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

=head1 UNIQUE CONSTRAINTS

=head2 C<event_id>

=over 4

=item * L</event_id>

=item * L</role_pair_id>

=back

=cut

__PACKAGE__->add_unique_constraint("event_id", ["event_id", "role_pair_id"]);

=head2 C<event_id_2>

=over 4

=item * L</event_id>

=item * L</ordering>

=back

=cut

__PACKAGE__->add_unique_constraint("event_id_2", ["event_id", "ordering"]);

=head1 RELATIONS

=head2 event

Type: belongs_to

Related object: L<bacds::Scheduler::Schema::Result::Event>

=cut

__PACKAGE__->belongs_to(
  "event",
  "bacds::Scheduler::Schema::Result::Event",
  { event_id => "event_id" },
  { is_deferrable => 1, on_delete => "RESTRICT", on_update => "RESTRICT" },
);

=head2 role_pair

Type: belongs_to

Related object: L<bacds::Scheduler::Schema::Result::RolePair>

=cut

__PACKAGE__->belongs_to(
  "role_pair",
  "bacds::Scheduler::Schema::Result::RolePair",
  { role_pair_id => "role_pair_id" },
  { is_deferrable => 1, on_delete => "RESTRICT", on_update => "RESTRICT" },
);


# Created by DBIx::Class::Schema::Loader v0.07049 @ 2024-11-08 07:26:32
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:STLFeEXz4u0SlfOecDCfnQ


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
