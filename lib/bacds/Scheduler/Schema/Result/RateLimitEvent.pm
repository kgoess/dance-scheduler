use utf8;
package bacds::Scheduler::Schema::Result::RateLimitEvent;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

bacds::Scheduler::Schema::Result::RateLimitEvent

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

=head1 TABLE: C<rate_limit_events>

=cut

__PACKAGE__->table("rate_limit_events");

=head1 ACCESSORS

=head2 rate_limit_event_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 bucket

  data_type: 'varchar'
  is_nullable: 0
  size: 32

=head2 event_key

  data_type: 'varchar'
  is_nullable: 0
  size: 255

=head2 created_ts

  data_type: 'datetime'
  datetime_undef_if_invalid: 1
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "rate_limit_event_id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "bucket",
  { data_type => "varchar", is_nullable => 0, size => 32 },
  "event_key",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "created_ts",
  {
    data_type => "datetime",
    datetime_undef_if_invalid => 1,
    is_nullable => 0,
  },
);

=head1 PRIMARY KEY

=over 4

=item * L</rate_limit_event_id>

=back

=cut

__PACKAGE__->set_primary_key("rate_limit_event_id");


# Created by DBIx::Class::Schema::Loader v0.07052 @ 2026-10-16 08:34:04
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:ji4H73HqQDsr6EreXDVhbg


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
