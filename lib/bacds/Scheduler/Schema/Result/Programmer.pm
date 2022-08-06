use utf8;
package bacds::Scheduler::Schema::Result::Programmer;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

bacds::Scheduler::Schema::Result::Programmer

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

=head1 TABLE: C<programmers>

=cut

__PACKAGE__->table("programmers");

=head1 ACCESSORS

=head2 programmer_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 email

  data_type: 'varchar'
  is_nullable: 0
  size: 256

=head2 password_hash

  data_type: 'varchar'
  is_nullable: 1
  size: 128

=head2 is_superuser

  data_type: 'tinyint'
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
  "programmer_id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "email",
  { data_type => "varchar", is_nullable => 0, size => 256 },
  "password_hash",
  { data_type => "varchar", is_nullable => 1, size => 128 },
  "is_superuser",
  { data_type => "tinyint", is_nullable => 1 },
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

=item * L</programmer_id>

=back

=cut

__PACKAGE__->set_primary_key("programmer_id");

=head1 UNIQUE CONSTRAINTS

=head2 C<programmer_email_idx>

=over 4

=item * L</email>

=back

=cut

__PACKAGE__->add_unique_constraint("programmer_email_idx", ["email"]);

=head1 RELATIONS

=head2 programmer_series_maps

Type: has_many

Related object: L<bacds::Scheduler::Schema::Result::ProgrammerSeriesMap>

=cut

__PACKAGE__->has_many(
  "programmer_series_maps",
  "bacds::Scheduler::Schema::Result::ProgrammerSeriesMap",
  { "foreign.programmer_id" => "self.programmer_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07049 @ 2022-08-05 19:21:08
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:lBSm7pyEKMURwB917xX3tQ


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
