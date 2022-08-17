use utf8;
package bacds::Scheduler::Schema::Result::ProgrammerEventsMap;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

bacds::Scheduler::Schema::Result::ProgrammerEventsMap

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

=head1 TABLE: C<programmer_events_map>

=cut

__PACKAGE__->table("programmer_events_map");

=head1 ACCESSORS

=head2 programmer_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 ordering

  data_type: 'integer'
  is_nullable: 1

=head2 event_id

  data_type: 'integer'
  is_foreign_key: 1
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
  "programmer_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "ordering",
  { data_type => "integer", is_nullable => 1 },
  "event_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
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

=head1 UNIQUE CONSTRAINTS

=head2 C<programmer_id>

=over 4

=item * L</programmer_id>

=item * L</event_id>

=back

=cut

__PACKAGE__->add_unique_constraint("programmer_id", ["programmer_id", "event_id"]);

=head1 RELATIONS

=head2 event

Type: belongs_to

Related object: L<bacds::Scheduler::Schema::Result::Event>

=cut

__PACKAGE__->belongs_to(
  "event",
  "bacds::Scheduler::Schema::Result::Event",
  { event_id => "event_id" },
  { is_deferrable => 1, on_delete => "RESTRICT", on_update => "RESTRICT" },
);

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


# Created by DBIx::Class::Schema::Loader v0.07049 @ 2022-08-16 19:44:58
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:ZdRNo8wqcNgIUhngo1buWA


use Role::Tiny::With;
with 'bacds::Scheduler::Schema::Role::AutoTimestamps';
1;
