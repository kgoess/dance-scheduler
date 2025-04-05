use utf8;
package bacds::Scheduler::Schema::Result::Page;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

bacds::Scheduler::Schema::Result::Page

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

=head1 TABLE: C<pages>

=cut

__PACKAGE__->table("pages");

=head1 ACCESSORS

=head2 page_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 title

  data_type: 'varchar'
  is_nullable: 0
  size: 191

=head2 url_path

  data_type: 'varchar'
  is_nullable: 0
  size: 191

=head2 short_desc

  data_type: 'varchar'
  is_nullable: 1
  size: 512

=head2 body

  data_type: 'mediumtext'
  is_nullable: 0

=head2 sidebar

  data_type: 'mediumtext'
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

=head2 is_deleted

  data_type: 'tinyint'
  default_value: 0
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "page_id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "title",
  { data_type => "varchar", is_nullable => 0, size => 191 },
  "url_path",
  { data_type => "varchar", is_nullable => 0, size => 191 },
  "short_desc",
  { data_type => "varchar", is_nullable => 1, size => 512 },
  "body",
  { data_type => "mediumtext", is_nullable => 0 },
  "sidebar",
  { data_type => "mediumtext", is_nullable => 1 },
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
  "is_deleted",
  { data_type => "tinyint", default_value => 0, is_nullable => 0 },
);

=head1 PRIMARY KEY

=over 4

=item * L</page_id>

=back

=cut

__PACKAGE__->set_primary_key("page_id");

=head1 UNIQUE CONSTRAINTS

=head2 C<page_url_idx>

=over 4

=item * L</url_path>

=back

=cut

__PACKAGE__->add_unique_constraint("page_url_idx", ["url_path"]);


# Created by DBIx::Class::Schema::Loader v0.07049 @ 2025-04-04 20:01:36
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:Esh8DTAEEIFEE+UP/3xazA


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
