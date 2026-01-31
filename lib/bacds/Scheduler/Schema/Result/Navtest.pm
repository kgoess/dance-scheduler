use utf8;
package bacds::Scheduler::Schema::Result::Navtest;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

bacds::Scheduler::Schema::Result::Navtest

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

=head1 TABLE: C<navtest>

=cut

__PACKAGE__->table("navtest");

=head1 ACCESSORS

=head2 entry_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 parent_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

=head2 url_part

  data_type: 'varchar'
  is_nullable: 0
  size: 191

=head2 description

  data_type: 'varchar'
  is_nullable: 1
  size: 2048

=head2 target_page_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

=head2 target_page_path

  data_type: 'varchar'
  is_nullable: 1
  size: 191

=cut

__PACKAGE__->add_columns(
  "entry_id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "parent_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "url_part",
  { data_type => "varchar", is_nullable => 0, size => 191 },
  "description",
  { data_type => "varchar", is_nullable => 1, size => 2048 },
  "target_page_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "target_page_path",
  { data_type => "varchar", is_nullable => 1, size => 191 },
);

=head1 PRIMARY KEY

=over 4

=item * L</entry_id>

=back

=cut

__PACKAGE__->set_primary_key("entry_id");

=head1 RELATIONS

=head2 navtests

Type: has_many

Related object: L<bacds::Scheduler::Schema::Result::Navtest>

=cut

__PACKAGE__->has_many(
  "navtests",
  "bacds::Scheduler::Schema::Result::Navtest",
  { "foreign.parent_id" => "self.entry_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 parent

Type: belongs_to

Related object: L<bacds::Scheduler::Schema::Result::Navtest>

=cut

__PACKAGE__->belongs_to(
  "parent",
  "bacds::Scheduler::Schema::Result::Navtest",
  { entry_id => "parent_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "RESTRICT",
    on_update     => "RESTRICT",
  },
);

=head2 target_page

Type: belongs_to

Related object: L<bacds::Scheduler::Schema::Result::Page>

=cut

__PACKAGE__->belongs_to(
  "target_page",
  "bacds::Scheduler::Schema::Result::Page",
  { page_id => "target_page_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "RESTRICT",
    on_update     => "RESTRICT",
  },
);


# Created by DBIx::Class::Schema::Loader v0.07052 @ 2026-01-31 12:07:22
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:T0gsdIwVLtOfd7n91xFRYQ


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
