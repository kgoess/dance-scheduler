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


# Created by DBIx::Class::Schema::Loader v0.07049 @ 2022-04-27 19:52:02
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:/pgvLY95Dihqz5leTt1WCg

use Role::Tiny::With;
with 'bacds::Scheduler::Model::Time';
1;
