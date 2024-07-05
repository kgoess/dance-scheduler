use utf8;
package bacds::Scheduler::Schema::Result::Venue;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

bacds::Scheduler::Schema::Result::Venue

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

=head1 TABLE: C<venues>

=cut

__PACKAGE__->table("venues");

=head1 ACCESSORS

=head2 venue_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 vkey

  data_type: 'char'
  is_nullable: 0
  size: 10

=head2 hall_name

  data_type: 'varchar'
  is_nullable: 0
  size: 128

=head2 address

  data_type: 'varchar'
  is_nullable: 1
  size: 255

=head2 city

  data_type: 'varchar'
  is_nullable: 1
  size: 64

=head2 zip

  data_type: 'char'
  is_nullable: 1
  size: 10

=head2 sidebar

  data_type: 'longtext'
  is_nullable: 1

=head2 directions

  data_type: 'longtext'
  is_nullable: 1

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

=cut

__PACKAGE__->add_columns(
  "venue_id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "vkey",
  { data_type => "char", is_nullable => 0, size => 10 },
  "hall_name",
  { data_type => "varchar", is_nullable => 0, size => 128 },
  "address",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "city",
  { data_type => "varchar", is_nullable => 1, size => 64 },
  "zip",
  { data_type => "char", is_nullable => 1, size => 10 },
  "sidebar",
  { data_type => "longtext", is_nullable => 1 },
  "directions",
  { data_type => "longtext", is_nullable => 1 },
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
);

=head1 PRIMARY KEY

=over 4

=item * L</venue_id>

=back

=cut

__PACKAGE__->set_primary_key("venue_id");

=head1 UNIQUE CONSTRAINTS

=head2 C<hall_name>

=over 4

=item * L</hall_name>

=back

=cut

__PACKAGE__->add_unique_constraint("hall_name", ["hall_name"]);

=head2 C<vkey_idx>

=over 4

=item * L</vkey>

=back

=cut

__PACKAGE__->add_unique_constraint("vkey_idx", ["vkey"]);

=head1 RELATIONS

=head2 event_venues_maps

Type: has_many

Related object: L<bacds::Scheduler::Schema::Result::EventVenuesMap>

=cut

__PACKAGE__->has_many(
  "event_venues_maps",
  "bacds::Scheduler::Schema::Result::EventVenuesMap",
  { "foreign.venue_id" => "self.venue_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07049 @ 2024-07-04 17:04:21
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:pByPM9OqRH6DdKKY0qqMfQ

use Role::Tiny::With;
with 'bacds::Scheduler::Schema::Role::AutoTimestamps';

__PACKAGE__->many_to_many(events=> 'event_venues_maps', 'event');

sub get_fields_for_event_row {
    my ($self) = @_;
    return {
        id   => $self->venue_id,
        name => $self->vkey,
    };
};

1;
