use utf8;
package bacds::Scheduler::Schema::Result::MemberToken;

use strict;
use warnings;

use base 'DBIx::Class::Core';

__PACKAGE__->load_components("InflateColumn::DateTime");

__PACKAGE__->table("member_tokens");

__PACKAGE__->add_columns(
    "token_id",
    { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
    "token",
    { data_type => "varchar", is_nullable => 0, size => 64 },
    "civicrm_contact_id",
    { data_type => "integer", is_nullable => 0 },
    "created_ts",
    { data_type => "datetime", datetime_undef_if_invalid => 1, is_nullable => 0 },
    "expires_ts",
    { data_type => "datetime", datetime_undef_if_invalid => 1, is_nullable => 0 },
    "used_ts",
    { data_type => "datetime", datetime_undef_if_invalid => 1, is_nullable => 1 },
);

__PACKAGE__->set_primary_key("token_id");

__PACKAGE__->add_unique_constraint("member_token_idx", ["token"]);

1;
