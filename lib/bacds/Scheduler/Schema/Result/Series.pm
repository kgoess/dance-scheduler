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

=head2 short_desc

  data_type: 'varchar'
  is_nullable: 1
  size: 2048

=head2 sidebar

  data_type: 'text'
  is_nullable: 1

=head2 display_text

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
  "short_desc",
  { data_type => "varchar", is_nullable => 1, size => 2048 },
  "sidebar",
  { data_type => "text", is_nullable => 1 },
  "display_text",
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

=head2 programmer_series_maps

Type: has_many

Related object: L<bacds::Scheduler::Schema::Result::ProgrammerSeriesMap>

=cut

__PACKAGE__->has_many(
  "programmer_series_maps",
  "bacds::Scheduler::Schema::Result::ProgrammerSeriesMap",
  { "foreign.series_id" => "self.series_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07049 @ 2022-08-05 19:21:08
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:Jaz5J9nlkC/Y5dzJjJpy9w
# These lines were loaded from '/var/lib/dance-scheduler/lib/perl5/bacds/Scheduler/Schema/Result/Series.pm' found in @INC.
# They are now part of the custom portion of this file
# for you to hand-edit.  If you do not either delete
# this section or remove that file from @INC, this section
# will be repeated redundantly when you re-create this
# file again via Loader!  See skip_load_external to disable
# this feature.

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

=head2 short_desc

  data_type: 'varchar'
  is_nullable: 1
  size: 2048

=head2 sidebar

  data_type: 'text'
  is_nullable: 1

=head2 display_text

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
  "short_desc",
  { data_type => "varchar", is_nullable => 1, size => 2048 },
  "sidebar",
  { data_type => "text", is_nullable => 1 },
  "display_text",
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


# Created by DBIx::Class::Schema::Loader v0.07049 @ 2022-07-15 19:47:11
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:j1mgEYYQTUCWEu8LxjpXAA

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
# End of lines loaded from '/var/lib/dance-scheduler/lib/perl5/bacds/Scheduler/Schema/Result/Series.pm'

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
