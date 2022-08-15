use utf8;
package bacds::Scheduler::Schema::Result::Style;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

bacds::Scheduler::Schema::Result::Style

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

=head1 TABLE: C<styles>

=cut

__PACKAGE__->table("styles");

=head1 ACCESSORS

=head2 style_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 name

  data_type: 'varchar'
  is_nullable: 0
  size: 255

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
  "style_id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "name",
  { data_type => "varchar", is_nullable => 0, size => 255 },
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

=item * L</style_id>

=back

=cut

__PACKAGE__->set_primary_key("style_id");

=head1 UNIQUE CONSTRAINTS

=head2 C<styles_id_idx>

=over 4

=item * L</name>

=back

=cut

__PACKAGE__->add_unique_constraint("styles_id_idx", ["name"]);

=head1 RELATIONS

=head2 event_styles_maps

Type: has_many

Related object: L<bacds::Scheduler::Schema::Result::EventStylesMap>

=cut

__PACKAGE__->has_many(
  "event_styles_maps",
  "bacds::Scheduler::Schema::Result::EventStylesMap",
  { "foreign.style_id" => "self.style_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07049 @ 2022-08-14 18:34:32
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:mp+F3rf7dUpVP+4mDUz9+w



__PACKAGE__->many_to_many(events=> 'event_styles_maps', 'event');

sub get_fields_for_event_row {
    my ($self) = @_;
    return {
        name => $self->name,
        id   => $self->style_id,
    };
}

use Role::Tiny::With;
with 'bacds::Scheduler::Schema::Role::AutoTimestamps';
1;
