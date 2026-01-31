use utf8;
package bacds::Scheduler::Schema::Result::TeamStylesMap;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

bacds::Scheduler::Schema::Result::TeamStylesMap

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

=head1 TABLE: C<team_styles_map>

=cut

__PACKAGE__->table("team_styles_map");

=head1 ACCESSORS

=head2 team_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 style_id

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
  default_value: 'current_timestamp()'
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "team_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "style_id",
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
    default_value => "current_timestamp()",
    is_nullable => 0,
  },
);

=head1 UNIQUE CONSTRAINTS

=head2 C<team_id>

=over 4

=item * L</team_id>

=item * L</ordering>

=back

=cut

__PACKAGE__->add_unique_constraint("team_id", ["team_id", "ordering"]);

=head2 C<team_styles_map_idx>

=over 4

=item * L</team_id>

=item * L</style_id>

=back

=cut

__PACKAGE__->add_unique_constraint("team_styles_map_idx", ["team_id", "style_id"]);

=head1 RELATIONS

=head2 style

Type: belongs_to

Related object: L<bacds::Scheduler::Schema::Result::Style>

=cut

__PACKAGE__->belongs_to(
  "style",
  "bacds::Scheduler::Schema::Result::Style",
  { style_id => "style_id" },
  { is_deferrable => 1, on_delete => "RESTRICT", on_update => "RESTRICT" },
);

=head2 team

Type: belongs_to

Related object: L<bacds::Scheduler::Schema::Result::Team>

=cut

__PACKAGE__->belongs_to(
  "team",
  "bacds::Scheduler::Schema::Result::Team",
  { team_id => "team_id" },
  { is_deferrable => 1, on_delete => "RESTRICT", on_update => "RESTRICT" },
);


# Created by DBIx::Class::Schema::Loader v0.07052 @ 2026-01-31 12:25:17
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:2eYrAFe48vuIpTRFVPp7BQ

use Role::Tiny::With;
with 'bacds::Scheduler::Schema::Role::AutoTimestamps';
1;
