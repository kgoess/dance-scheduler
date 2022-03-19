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
  is_nullable: 0

=head2 talent_id

  data_type: 'integer'
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "band_id",
  { data_type => "integer", is_nullable => 0 },
  "talent_id",
  { data_type => "integer", is_nullable => 0 },
);

=head1 UNIQUE CONSTRAINTS

=head2 C<band_membership_idx>

=over 4

=item * L</band_id>

=item * L</talent_id>

=back

=cut

__PACKAGE__->add_unique_constraint("band_membership_idx", ["band_id", "talent_id"]);


# Created by DBIx::Class::Schema::Loader v0.07049 @ 2022-03-19 14:26:53
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:2AHO5TAay8ESfRtZOFosXg


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
