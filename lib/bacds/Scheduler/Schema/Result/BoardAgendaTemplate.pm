package bacds::Scheduler::Schema::Result::BoardAgendaTemplate;

use strict;
use warnings;
use base 'DBIx::Class::Core';

use Role::Tiny::With;
with 'bacds::Scheduler::Schema::Role::AutoTimestamps';

__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("board_agenda_template");

__PACKAGE__->add_columns(
    board_agenda_template_id =>
        { data_type => 'integer', is_auto_increment => 1 },
    agenda_text =>
        { data_type => 'text',    default_value => '' },
    zoom_url    =>
        { data_type => 'varchar', size => 512, default_value => '' },
    created_ts  =>
        { data_type => 'datetime',  inflate_datetime => 1 },
    modified_ts =>
        { data_type => 'timestamp', inflate_datetime => 1 },
);

__PACKAGE__->set_primary_key('board_agenda_template_id');

1;
