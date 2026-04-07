use utf8;
package bacds::Scheduler::Schema::Result::BoardAgenda;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

bacds::Scheduler::Schema::Result::BoardAgenda

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

=head1 TABLE: C<board_agenda>

=cut

__PACKAGE__->table("board_agenda");

=head1 ACCESSORS

=head2 board_agenda_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 meeting_date

  data_type: 'date'
  datetime_undef_if_invalid: 1
  is_nullable: 0

=head2 agenda_text

  data_type: 'text'
  default_value: ''''
  is_nullable: 0

=head2 created_ts

  data_type: 'datetime'
  datetime_undef_if_invalid: 1
  is_nullable: 0

=head2 modified_ts

  data_type: 'timestamp'
  datetime_undef_if_invalid: 1
  is_nullable: 0

=head2 draft_minutes_url

  data_type: 'varchar'
  default_value: (empty string)
  is_nullable: 0
  size: 512

=cut

__PACKAGE__->add_columns(
  "board_agenda_id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "meeting_date",
  { data_type => "date", datetime_undef_if_invalid => 1, is_nullable => 0 },
  "agenda_text",
  { data_type => "text", default_value => "''", is_nullable => 0 },
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
    is_nullable => 0,
  },
  "draft_minutes_url",
  { data_type => "varchar", default_value => "", is_nullable => 0, size => 512 },
);

=head1 PRIMARY KEY

=over 4

=item * L</board_agenda_id>

=back

=cut

__PACKAGE__->set_primary_key("board_agenda_id");


# Created by DBIx::Class::Schema::Loader v0.07052 @ 2026-04-07 06:42:58
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:dhhfoKfLPI/J6Yes7RUKgQ


# You can replace this text with custom code or comments, and it will be preserved on regeneration

use Role::Tiny::With;
with 'bacds::Scheduler::Schema::Role::AutoTimestamps';

1;
