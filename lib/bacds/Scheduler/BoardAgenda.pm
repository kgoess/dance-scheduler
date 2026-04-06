=head1 NAME

bacds::Scheduler::BoardAgenda - handles the board agenda

=head1 SYNOPSIS

Just this in bacds::Scheduler

    use bacds::Scheduler::BoardAgenda; # loads routes under /board-agenda/

Links are in the sidebar on https://bacds.org/series/board/

=head1 DESCRIPTION

The point of this was to make a permalink that would also work for the next
board meeting and auto-reset itself when the meeting date has passed. It gives
the Board Chair a place to incrementally add items to the agenda as they come
in and be able to hit the "copy to clipboard" button to send them out in an
email without having to manually remove the zoom link.

There are two tables: board_agenda with the current agenda and
board_agenda_template with the vanilla base agenda.

This could just about be a separate Dancer2 app instead of merging it into the
main dance-scheduler app via `use Dancer2 appname => 'bacds::Scheduler';`

This might also have been able to be an accordion under the dance-scheduler UI,
but I used Claude to generate most of the code for me and didn't feel like
reworking it all to fit in the JSON model.

=head1 ROUTES

=cut

package bacds::Scheduler::BoardAgenda;

use 5.32.1;
use warnings;

use Dancer2 appname => 'bacds::Scheduler';

use bacds::Scheduler::Model::BoardAgenda;
use bacds::Scheduler::Plugin::Auth;

=head2 get /board-agenda

Public permalink - no login required

After the meeting date has passed it automatically reverts to the board_agenda_template.

=cut

get '/board-agenda' => sub {
    my $text = bacds::Scheduler::Model::BoardAgenda->get_public_text();
    template 'board-agenda/public' => {
        agenda_text => $text,
        page_title  => 'BACDS Board Meeting Agenda',
    },
    { layout => 'unearth-page-wrapper' };
};

=head2 get /board-agenda/edit

Chairman's edit form - login required

=cut

get '/board-agenda/edit' => requires_login sub {
    my $row = bacds::Scheduler::Model::BoardAgenda->get_current_agenda();
    my $template = bacds::Scheduler::Model::BoardAgenda
        ->get_template_row();

    template 'board-agenda/edit' => {
        title        => 'Edit Board Agenda',
        signed_in_as => vars->{signed_in_as}->email,
        meeting_date => $row ? $row->meeting_date->strftime('%Y-%m-%d') : '',
        agenda_text  => $row ? $row->agenda_text  : $template->agenda_text,
        zoom_url     => $template->zoom_url,
        last_updated => $row ? $row->modified_ts
                                   ->set_time_zone('UTC')
                                   ->set_time_zone('local')
                                   ->datetime(' ')
                             : 'not yet updated',
    },
    { layout => 'unearth-page-wrapper' };
};

=head2 post /board-agenda/edit

Accepts submission of the edit form, does post-redirect-get.

=cut

post '/board-agenda/edit' => requires_login sub {
    my $meeting_date = body_parameters->get('meeting_date')
        or send_error 'missing meeting_date' => 400;
    my $agenda_text = body_parameters->get('agenda_text') // '';

    bacds::Scheduler::Model::BoardAgenda->save_agenda(
        meeting_date => $meeting_date,
        agenda_text  => $agenda_text,
    );
    redirect uri_for('/board-agenda/edit') => 303;
};

=head2 get /board-agenda/email-text

JSON endpoint for the "copy with zoom" button

=cut

get '/board-agenda/email-text' => requires_login sub {
    my $text = bacds::Scheduler::Model::BoardAgenda->get_email_text();
    send_as JSON => { text => $text };
};



=head2 get /board-agenda/template

Template edit form (chairman edits the standing template + zoom URL)

=cut

get '/board-agenda/template' => requires_login sub {
    my $tmpl = bacds::Scheduler::Model::BoardAgenda->get_template_row();

    template 'board-agenda/edit-template' => {
        title        => 'Edit Agenda Template',
        signed_in_as => vars->{signed_in_as}->email,
        agenda_text  => $tmpl ? $tmpl->agenda_text : '',
        zoom_url     => $tmpl ? $tmpl->zoom_url     : '',
        last_updated => $tmpl ? $tmpl->modified_ts
                                     ->set_time_zone('UTC')
                                     ->set_time_zone('local')
                                     ->datetime(' ')
                             : 'not yet updated',
    },
    { layout => 'unearth-page-wrapper' };
};

=head2 post /board-agenda/template

Accepts POST update for the standing template, does post-redirect-get

=cut

post '/board-agenda/template' => requires_login sub {
    my $agenda_text = body_parameters->get('agenda_text') // '';
    my $zoom_url    = body_parameters->get('zoom_url')    // '';

    bacds::Scheduler::Model::BoardAgenda->save_template(
        agenda_text => $agenda_text,
        zoom_url    => $zoom_url,
    );
    redirect uri_for('/board-agenda/template') => 303;
};
