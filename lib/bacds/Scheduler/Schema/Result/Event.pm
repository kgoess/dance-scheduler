use utf8;
package bacds::Scheduler::Schema::Result::Event;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

bacds::Scheduler::Schema::Result::Event

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

=head1 TABLE: C<events>

=cut

__PACKAGE__->table("events");

=head1 ACCESSORS

=head2 event_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 name

  data_type: 'varchar'
  is_nullable: 1
  size: 256

=head2 start_time

  data_type: 'datetime'
  datetime_undef_if_invalid: 1
  is_nullable: 0

=head2 end_time

  data_type: 'datetime'
  datetime_undef_if_invalid: 1
  is_nullable: 1

=head2 is_camp

  data_type: 'tinyint'
  is_nullable: 1

=head2 long_desc

  data_type: 'mediumtext'
  is_nullable: 1

=head2 short_desc

  data_type: 'varchar'
  is_nullable: 1
  size: 1024

=head2 is_template

  data_type: 'tinyint'
  is_nullable: 1

=head2 series_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

=head2 is_deleted

  data_type: 'tinyint'
  is_nullable: 1

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
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "name",
  { data_type => "varchar", is_nullable => 1, size => 256 },
  "start_time",
  {
    data_type => "datetime",
    datetime_undef_if_invalid => 1,
    is_nullable => 0,
  },
  "end_time",
  {
    data_type => "datetime",
    datetime_undef_if_invalid => 1,
    is_nullable => 1,
  },
  "is_camp",
  { data_type => "tinyint", is_nullable => 1 },
  "long_desc",
  { data_type => "mediumtext", is_nullable => 1 },
  "short_desc",
  { data_type => "varchar", is_nullable => 1, size => 1024 },
  "is_template",
  { data_type => "tinyint", is_nullable => 1 },
  "series_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "is_deleted",
  { data_type => "tinyint", is_nullable => 1 },
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

=item * L</event_id>

=back

=cut

__PACKAGE__->set_primary_key("event_id");

=head1 UNIQUE CONSTRAINTS

=head2 C<series_id>

=over 4

=item * L</series_id>

=item * L</is_template>

=back

=cut

__PACKAGE__->add_unique_constraint("series_id", ["series_id", "is_template"]);

=head1 RELATIONS

=head2 event_band_maps

Type: has_many

Related object: L<bacds::Scheduler::Schema::Result::EventBandMap>

=cut

__PACKAGE__->has_many(
  "event_band_maps",
  "bacds::Scheduler::Schema::Result::EventBandMap",
  { "foreign.event_id" => "self.event_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 event_callers_maps

Type: has_many

Related object: L<bacds::Scheduler::Schema::Result::EventCallersMap>

=cut

__PACKAGE__->has_many(
  "event_callers_maps",
  "bacds::Scheduler::Schema::Result::EventCallersMap",
  { "foreign.event_id" => "self.event_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 event_parent_orgs_maps

Type: has_many

Related object: L<bacds::Scheduler::Schema::Result::EventParentOrgsMap>

=cut

__PACKAGE__->has_many(
  "event_parent_orgs_maps",
  "bacds::Scheduler::Schema::Result::EventParentOrgsMap",
  { "foreign.event_id" => "self.event_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 event_styles_maps

Type: has_many

Related object: L<bacds::Scheduler::Schema::Result::EventStylesMap>

=cut

__PACKAGE__->has_many(
  "event_styles_maps",
  "bacds::Scheduler::Schema::Result::EventStylesMap",
  { "foreign.event_id" => "self.event_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 event_talent_maps

Type: has_many

Related object: L<bacds::Scheduler::Schema::Result::EventTalentMap>

=cut

__PACKAGE__->has_many(
  "event_talent_maps",
  "bacds::Scheduler::Schema::Result::EventTalentMap",
  { "foreign.event_id" => "self.event_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 event_venues_maps

Type: has_many

Related object: L<bacds::Scheduler::Schema::Result::EventVenuesMap>

=cut

__PACKAGE__->has_many(
  "event_venues_maps",
  "bacds::Scheduler::Schema::Result::EventVenuesMap",
  { "foreign.event_id" => "self.event_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 series

Type: belongs_to

Related object: L<bacds::Scheduler::Schema::Result::Series>

=cut

__PACKAGE__->belongs_to(
  "series",
  "bacds::Scheduler::Schema::Result::Series",
  { series_id => "series_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "RESTRICT",
    on_update     => "RESTRICT",
  },
);


# Created by DBIx::Class::Schema::Loader v0.07049 @ 2022-06-14 20:20:47
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:q6qPndHJKspoTWBn/S1O9A

__PACKAGE__->many_to_many(bands => 'event_band_maps', 'band');
__PACKAGE__->many_to_many(callers => 'event_callers_maps', 'caller');
__PACKAGE__->many_to_many(parent_orgs => 'event_parent_orgs_maps', 'parent_org');
__PACKAGE__->many_to_many(styles => 'event_styles_maps', 'style');
__PACKAGE__->many_to_many(talent => 'event_talent_maps', 'talent');
__PACKAGE__->many_to_many(venues => 'event_venues_maps', 'venue');

use Role::Tiny::With;
with 'bacds::Scheduler::Schema::Role::AutoTimestamps';

1;
