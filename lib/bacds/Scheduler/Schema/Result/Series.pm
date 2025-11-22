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

=head2 series_xid

  data_type: 'char'
  is_nullable: 0
  size: 24

=head2 name

  data_type: 'varchar'
  is_nullable: 1
  size: 191

=head2 frequency

  data_type: 'varchar'
  is_nullable: 1
  size: 128

=head2 short_desc

  data_type: 'varchar'
  is_nullable: 1
  size: 2048

=head2 sidebar

  data_type: 'longtext'
  is_nullable: 1

=head2 display_text

  data_type: 'longtext'
  is_nullable: 1

=head2 series_url

  data_type: 'varchar'
  is_nullable: 1
  size: 255

=head2 manager

  data_type: 'varchar'
  is_nullable: 1
  size: 255

=head2 programmer_notes

  data_type: 'longtext'
  is_nullable: 1

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

=head2 photo_url

  data_type: 'varchar'
  is_nullable: 1
  size: 255

=cut

__PACKAGE__->add_columns(
  "series_id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "series_xid",
  { data_type => "char", is_nullable => 0, size => 24 },
  "name",
  { data_type => "varchar", is_nullable => 1, size => 191 },
  "frequency",
  { data_type => "varchar", is_nullable => 1, size => 128 },
  "short_desc",
  { data_type => "varchar", is_nullable => 1, size => 2048 },
  "sidebar",
  { data_type => "longtext", is_nullable => 1 },
  "display_text",
  { data_type => "longtext", is_nullable => 1 },
  "series_url",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "manager",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "programmer_notes",
  { data_type => "longtext", is_nullable => 1 },
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
  "photo_url",
  { data_type => "varchar", is_nullable => 1, size => 255 },
);

=head1 PRIMARY KEY

=over 4

=item * L</series_id>

=back

=cut

__PACKAGE__->set_primary_key("series_id");

=head1 UNIQUE CONSTRAINTS

=head2 C<series_xid_idx>

=over 4

=item * L</series_xid>

=back

=cut

__PACKAGE__->add_unique_constraint("series_xid_idx", ["series_xid"]);

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


# Created by DBIx::Class::Schema::Loader v0.07049 @ 2024-11-07 19:11:50
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:GRhT+PO6zJ8Gc4v8biCkfQ

use Role::Tiny::With;
with 'bacds::Scheduler::Schema::Role::AutoTimestamps';

sub get_fields_for_event_row {
    my ($self) = @_;
    return {
        id => $self->series_id,
        name => $self->name,
    };
}

sub get_fields_for_programmer_row {
    my ($self) = @_;
    return {
        id => $self->series_id,
        name => $self->name,
    };
}

sub get_canonical_url {
    my ($self, $scheme, $host) = @_;
    my $series_url = $self->series_url;
    if ($series_url =~ /^http/) {
        return $series_url;
    }
    return join '',
        "$scheme://",
        $host,
        $series_url,
}

1;
