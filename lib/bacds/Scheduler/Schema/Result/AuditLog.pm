use utf8;
package bacds::Scheduler::Schema::Result::AuditLog;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

bacds::Scheduler::Schema::Result::AuditLog

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

=head1 TABLE: C<audit_logs>

=cut

__PACKAGE__->table("audit_logs");

=head1 ACCESSORS

=head2 audit_log_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 programmer_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 target

  data_type: 'varchar'
  is_nullable: 0
  size: 64

=head2 target_id

  data_type: 'integer'
  is_nullable: 1

=head2 action

  data_type: 'varchar'
  is_nullable: 0
  size: 64

=head2 message

  data_type: 'varchar'
  is_nullable: 0
  size: 2048

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
  "audit_log_id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "programmer_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "target",
  { data_type => "varchar", is_nullable => 0, size => 64 },
  "target_id",
  { data_type => "integer", is_nullable => 1 },
  "action",
  { data_type => "varchar", is_nullable => 0, size => 64 },
  "message",
  { data_type => "varchar", is_nullable => 0, size => 2048 },
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

=item * L</audit_log_id>

=back

=cut

__PACKAGE__->set_primary_key("audit_log_id");

=head1 RELATIONS

=head2 programmer

Type: belongs_to

Related object: L<bacds::Scheduler::Schema::Result::Programmer>

=cut

__PACKAGE__->belongs_to(
  "programmer",
  "bacds::Scheduler::Schema::Result::Programmer",
  { programmer_id => "programmer_id" },
  { is_deferrable => 1, on_delete => "RESTRICT", on_update => "RESTRICT" },
);


# Created by DBIx::Class::Schema::Loader v0.07049 @ 2023-01-08 07:29:30
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:9Oa7NOQFy5NGz7GPZ/KdCA


use Role::Tiny::With;
with 'bacds::Scheduler::Schema::Role::AutoTimestamps';

1;
