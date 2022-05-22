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
  size: 256

=head2 city

  data_type: 'varchar'
  is_nullable: 1
  size: 64

=head2 zip

  data_type: 'char'
  is_nullable: 1
  size: 10

=head2 comment

  data_type: 'varchar'
  is_nullable: 1
  size: 32766

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
  "venue_id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "vkey",
  { data_type => "char", is_nullable => 0, size => 10 },
  "hall_name",
  { data_type => "varchar", is_nullable => 0, size => 128 },
  "address",
  { data_type => "varchar", is_nullable => 1, size => 256 },
  "city",
  { data_type => "varchar", is_nullable => 1, size => 64 },
  "zip",
  { data_type => "char", is_nullable => 1, size => 10 },
  "comment",
  { data_type => "varchar", is_nullable => 1, size => 32766 },
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

=item * L</venue_id>

=back

=cut

__PACKAGE__->set_primary_key("venue_id");

=head1 UNIQUE CONSTRAINTS

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


# Created by DBIx::Class::Schema::Loader v0.07049 @ 2022-04-27 19:52:02
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:LRCdL+ARtoyFYCcKEkgVXA



use Role::Tiny::With;
with 'bacds::Scheduler::Schema::Role::AutoTimestamps';
1;
