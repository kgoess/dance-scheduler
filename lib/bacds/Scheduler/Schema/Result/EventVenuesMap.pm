use utf8;
package bacds::Scheduler::Schema::Result::EventVenuesMap;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

bacds::Scheduler::Schema::Result::EventVenuesMap

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

=head1 TABLE: C<event_venues_map>

=cut

__PACKAGE__->table("event_venues_map");

=head1 ACCESSORS

=head2 event_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 venue_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 ordering

  data_type: 'integer'
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "event_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "venue_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "ordering",
  { data_type => "integer", is_nullable => 0 },
);

=head1 UNIQUE CONSTRAINTS

=head2 C<event_id>

=over 4

=item * L</event_id>

=item * L</venue_id>

=back

=cut

__PACKAGE__->add_unique_constraint("event_id", ["event_id", "venue_id"]);

=head2 C<event_id_2>

=over 4

=item * L</event_id>

=item * L</ordering>

=back

=cut

__PACKAGE__->add_unique_constraint("event_id_2", ["event_id", "ordering"]);

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

=head2 venue

Type: belongs_to

Related object: L<bacds::Scheduler::Schema::Result::Venue>

=cut

__PACKAGE__->belongs_to(
  "venue",
  "bacds::Scheduler::Schema::Result::Venue",
  { venue_id => "venue_id" },
  { is_deferrable => 1, on_delete => "RESTRICT", on_update => "RESTRICT" },
);


# Created by DBIx::Class::Schema::Loader v0.07049 @ 2022-03-19 14:26:53
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:lwHOjHgRjtEJmjsrH8DUhQ


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
