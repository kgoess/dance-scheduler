use utf8;
package bacds::Scheduler::Schema::Result::Series;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

bacds::Scheduler::Schema::Result::Series

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

=head1 TABLE: C<series>

=cut

__PACKAGE__->table("series");

=head1 ACCESSORS

=head2 series_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 name

  data_type: 'varchar'
  is_nullable: 1
  size: 256

=head2 frequency

  data_type: 'varchar'
  is_nullable: 1
  size: 128

=head2 default_style_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

=head2 default_venue_id

  data_type: 'integer'
  is_nullable: 1

=head2 default_parent_org_id

  data_type: 'integer'
  is_nullable: 1

=head2 default_start_time

  data_type: 'time'
  is_nullable: 1

=head2 default_end_time

  data_type: 'time'
  is_nullable: 1

=head2 display_notes

  data_type: 'text'
  is_nullable: 1

=head2 programmer_notes

  data_type: 'text'
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
  "series_id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "name",
  { data_type => "varchar", is_nullable => 1, size => 256 },
  "frequency",
  { data_type => "varchar", is_nullable => 1, size => 128 },
  "default_style_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "default_venue_id",
  { data_type => "integer", is_nullable => 1 },
  "default_parent_org_id",
  { data_type => "integer", is_nullable => 1 },
  "default_start_time",
  { data_type => "time", is_nullable => 1 },
  "default_end_time",
  { data_type => "time", is_nullable => 1 },
  "display_notes",
  { data_type => "text", is_nullable => 1 },
  "programmer_notes",
  { data_type => "text", is_nullable => 1 },
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

=item * L</series_id>

=back

=cut

__PACKAGE__->set_primary_key("series_id");

=head1 RELATIONS

=head2 default_style

Type: belongs_to

Related object: L<bacds::Scheduler::Schema::Result::Style>

=cut

__PACKAGE__->belongs_to(
  "default_style",
  "bacds::Scheduler::Schema::Result::Style",
  { style_id => "default_style_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "RESTRICT",
    on_update     => "RESTRICT",
  },
);

=head2 events

Type: has_many

Related object: L<bacds::Scheduler::Schema::Result::Event>

=cut

__PACKAGE__->has_many(
  "events",
  "bacds::Scheduler::Schema::Result::Event",
  { "foreign.series_id" => "self.series_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07049 @ 2022-06-15 20:12:06
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:lw5WrdnEMQZi1ClyiNtGcg

use Role::Tiny::With;
with 'bacds::Scheduler::Schema::Role::AutoTimestamps';

sub get_fields_for_event_row {
    my ($self) = @_;
    return {
        id => $self->series_id,
        name => $self->name,
    };
}

1;
