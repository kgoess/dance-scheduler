use utf8;
package bacds::Scheduler::Schema::Result::BandMembership;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

bacds::Scheduler::Schema::Result::BandMembership

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

=head1 TABLE: C<band_membership>

=cut

__PACKAGE__->table("band_membership");

=head1 ACCESSORS

=head2 band_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 talent_id

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
  "band_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "talent_id",
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

=head2 C<band_id>

=over 4

=item * L</band_id>

=item * L</ordering>

=back

=cut

__PACKAGE__->add_unique_constraint("band_id", ["band_id", "ordering"]);

=head2 C<band_membership_idx>

=over 4

=item * L</band_id>

=item * L</talent_id>

=back

=cut

__PACKAGE__->add_unique_constraint("band_membership_idx", ["band_id", "talent_id"]);

=head1 RELATIONS

=head2 band

Type: belongs_to

Related object: L<bacds::Scheduler::Schema::Result::Band>

=cut

__PACKAGE__->belongs_to(
  "band",
  "bacds::Scheduler::Schema::Result::Band",
  { band_id => "band_id" },
  { is_deferrable => 1, on_delete => "RESTRICT", on_update => "RESTRICT" },
);

=head2 talent

Type: belongs_to

Related object: L<bacds::Scheduler::Schema::Result::Talent>

=cut

__PACKAGE__->belongs_to(
  "talent",
  "bacds::Scheduler::Schema::Result::Talent",
  { talent_id => "talent_id" },
  { is_deferrable => 1, on_delete => "RESTRICT", on_update => "RESTRICT" },
);


# Created by DBIx::Class::Schema::Loader v0.07049 @ 2022-06-07 19:51:39
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:Qc6yR4REnQP7h4NGu6n4jQ


use Role::Tiny::With;
with 'bacds::Scheduler::Schema::Role::AutoTimestamps';
1;
