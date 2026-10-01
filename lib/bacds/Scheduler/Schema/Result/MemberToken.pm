use utf8;
package bacds::Scheduler::Schema::Result::MemberToken;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

bacds::Scheduler::Schema::Result::MemberToken

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

=head1 TABLE: C<member_tokens>

=cut

__PACKAGE__->table("member_tokens");

=head1 ACCESSORS

=head2 token_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 token

  data_type: 'varchar'
  is_nullable: 0
  size: 64

=head2 civicrm_contact_id

  data_type: 'integer'
  is_nullable: 0

=head2 created_ts

  data_type: 'datetime'
  datetime_undef_if_invalid: 1
  is_nullable: 0

=head2 expires_ts

  data_type: 'datetime'
  datetime_undef_if_invalid: 1
  is_nullable: 0

=head2 used_ts

  data_type: 'datetime'
  datetime_undef_if_invalid: 1
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "token_id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "token",
  { data_type => "varchar", is_nullable => 0, size => 64 },
  "civicrm_contact_id",
  { data_type => "integer", is_nullable => 0 },
  "created_ts",
  {
    data_type => "datetime",
    datetime_undef_if_invalid => 1,
    is_nullable => 0,
  },
  "expires_ts",
  {
    data_type => "datetime",
    datetime_undef_if_invalid => 1,
    is_nullable => 0,
  },
  "used_ts",
  {
    data_type => "datetime",
    datetime_undef_if_invalid => 1,
    is_nullable => 1,
  },
);

=head1 PRIMARY KEY

=over 4

=item * L</token_id>

=back

=cut

__PACKAGE__->set_primary_key("token_id");

=head1 UNIQUE CONSTRAINTS

=head2 C<member_token_idx>

=over 4

=item * L</token>

=back

=cut

__PACKAGE__->add_unique_constraint("member_token_idx", ["token"]);


# Created by DBIx::Class::Schema::Loader v0.07052 @ 2026-10-01 12:47:03
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:TJGOqK4pPfvqeB1AvLiTAw


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
