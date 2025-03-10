use utf8;
package bacds::Scheduler::Schema::Result::RolePair;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

bacds::Scheduler::Schema::Result::RolePair

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

=head1 TABLE: C<role_pairs>

=cut

__PACKAGE__->table("role_pairs");

=head1 ACCESSORS

=head2 role_pair_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 role_pair

  data_type: 'varchar'
  is_nullable: 0
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

=cut

__PACKAGE__->add_columns(
  "role_pair_id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "role_pair",
  { data_type => "varchar", is_nullable => 0, size => 191 },
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

=item * L</role_pair_id>

=back

=cut

__PACKAGE__->set_primary_key("role_pair_id");

=head1 UNIQUE CONSTRAINTS

=head2 C<role_pair_idx>

=over 4

=item * L</role_pair>

=back

=cut

__PACKAGE__->add_unique_constraint("role_pair_idx", ["role_pair"]);

=head1 RELATIONS

=head2 event_role_pairs_maps

Type: has_many

Related object: L<bacds::Scheduler::Schema::Result::EventRolePairsMap>

=cut

__PACKAGE__->has_many(
  "event_role_pairs_maps",
  "bacds::Scheduler::Schema::Result::EventRolePairsMap",
  { "foreign.role_pair_id" => "self.role_pair_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07049 @ 2024-11-08 07:26:32
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:ucqbfgEnfbQLYNzPLS+1SQ

use Role::Tiny::With;
with 'bacds::Scheduler::Schema::Role::AutoTimestamps';

__PACKAGE__->many_to_many(events => 'event_role_pairs_maps', 'event');


sub get_fields_for_event_row {
    my ($self) = @_;
    return {
        name => $self->role_pair,
        id   => $self->role_pair_id,
    };
}

1;
