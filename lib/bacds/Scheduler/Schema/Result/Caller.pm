use utf8;
package bacds::Scheduler::Schema::Result::Caller;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

bacds::Scheduler::Schema::Result::Caller

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

=head1 TABLE: C<callers>

=cut

__PACKAGE__->table("callers");

=head1 ACCESSORS

=head2 caller_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 name

  data_type: 'varchar'
  is_nullable: 0
  size: 256

=head2 created_ts

  data_type: 'timestamp'
  datetime_undef_if_invalid: 1
  default_value: current_timestamp
  is_nullable: 0

=head2 modified_ts

  data_type: 'timestamp'
  datetime_undef_if_invalid: 1
  default_value: '0000-00-00 00:00:00'
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "caller_id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "name",
  { data_type => "varchar", is_nullable => 0, size => 256 },
  "created_ts",
  {
    data_type => "timestamp",
    datetime_undef_if_invalid => 1,
    default_value => \"current_timestamp",
    is_nullable => 0,
  },
  "modified_ts",
  {
    data_type => "timestamp",
    datetime_undef_if_invalid => 1,
    default_value => "0000-00-00 00:00:00",
    is_nullable => 0,
  },
);

=head1 PRIMARY KEY

=over 4

=item * L</caller_id>

=back

=cut

__PACKAGE__->set_primary_key("caller_id");

=head1 UNIQUE CONSTRAINTS

=head2 C<caller_id_idx>

=over 4

=item * L</name>

=back

=cut

__PACKAGE__->add_unique_constraint("caller_id_idx", ["name"]);

=head1 RELATIONS

=head2 event_callers_maps

Type: has_many

Related object: L<bacds::Scheduler::Schema::Result::EventCallersMap>

=cut

__PACKAGE__->has_many(
  "event_callers_maps",
  "bacds::Scheduler::Schema::Result::EventCallersMap",
  { "foreign.caller_id" => "self.caller_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07049 @ 2022-03-19 14:26:53
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:m4WNmaoOIZW6gSzkPMHX2Q


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
