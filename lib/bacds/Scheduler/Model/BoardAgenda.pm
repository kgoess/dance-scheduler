=head1 NAME

bacds::Scheduler::Model::BoardAgenda - mediates db access for agenda

=head1 DESCRIPTION

Functions called by the routes in bacds::Scheduler::BoardAgenda, q.v. for details.

=head1 METHODS

=cut

package bacds::Scheduler::Model::BoardAgenda;

use 5.32.1;
use warnings;
use DateTime;
use bacds::Scheduler::Util::Db qw/get_dbh/;
use bacds::Scheduler::Util::Time qw/get_now/;


# ----------------------------------------------------------------
# Template methods
# ----------------------------------------------------------------

=head2 get_template_row

Returns the dbh result for the single row in the board_agenda_template table.

=cut

sub get_template_row {
    my ($class) = @_;
    my $dbh = get_dbh();
    # Always a single row; grab it
    return $dbh->resultset('BoardAgendaTemplate')
               ->search({}, { rows => 1 })
               ->single;
}


=head2 save_template

Updates the one row in the board_agenda_template table

=cut

sub save_template {
    my ($class, %args) = @_;
    # %args: agenda_text, zoom_url
    my $dbh = get_dbh();
    my $row = $dbh->resultset('BoardAgendaTemplate')
                  ->search({}, { rows => 1 })
                  ->single;
    if ($row) {
        $row->update({ %args });
    } else {
        $dbh->resultset('BoardAgendaTemplate')
            ->create({ %args });
    }
}

# ----------------------------------------------------------------
# Current agenda methods
# ----------------------------------------------------------------

=head2 get_current_agenda

If the meeting date is still in the future, then retrieves the single row in
the board_agenda table.

Otherwise returns undef.

=cut

sub get_current_agenda {
    my ($class) = @_;
    my $dbh = get_dbh();
    my $row = $dbh->resultset('BoardAgenda')->search(
        {},
        { order_by => { -desc => 'meeting_date' }, rows => 1 }
    )->single;

    return undef unless $row;

    # Expires: noon the day after the meeting
    my $now     = get_now();
    my $expires = $row->meeting_date->clone->add(days => 1)->set(hour => 12);

    return $now < $expires ? $row : undef;
}

=head2 save_agenda

Updates the single row in the board_agenda table.

=cut

sub save_agenda {
    my ($class, %args) = @_;
    # %args: meeting_date, agenda_text, draft_minutes_url
    # Note: zoom_url is NOT stored in board_agenda, it lives in the template
    my $dbh = get_dbh();
    my $now = get_now();
    my $existing = $dbh->resultset('BoardAgenda')->search(
        {},
        { order_by => { -desc => 'meeting_date' }, rows => 1 }
    )->single;

    if ($existing) {
        $existing->update({ %args, modified_ts => $now });
    } else {
        $dbh->resultset('BoardAgenda')
            ->create({ %args, created_ts => $now, modified_ts => $now });
    }
}

# ----------------------------------------------------------------
# Text rendering
# ----------------------------------------------------------------

=head2 get_public_text

Returns the text with the ZOOM LINK slug replaced with "Zoom link available to
board members".

From the logic in get_current_agenda, if the meeting date is in the past
then it returns the standing template.

=cut

sub get_public_text {
    my ($class) = @_;
    my $row = $class->get_current_agenda();
    my $tmpl = $class->get_template_row();
    my $text = $row ? $row->agenda_text : ($tmpl ? $tmpl->agenda_text : '');
    $text =~ s{\[ZOOM LINK\]}{[Zoom link available to board members]}g;
    $text =~ s{https://zoom.us[a-zA-Z0-9/?]+}{[Zoom link available to board members]}g; # failsafe
    if ($row) {
        if (my $meeting_date = $row->meeting_date->ymd) {
            $text =~ s{\[MEETING DATE\]}{$meeting_date}g;
        }

        # draft_minutes_url never goes to the public
        # if it's on a line by itself, remove the whole line
        # otherwise just remove the slug
        $text =~ s{
            (
                (?-x:^ *\[DRAFT MINUTES URL\](\n|\r\n)?)
                |
                (?-x:\[DRAFT MINUTES URL\])
            )
        }{}xmsg;

        # it starts out in the "floating" time_zone, so we have to start it at
        # UTC before converting
        my $updated = $row->modified_ts
            ->set_time_zone('UTC')
            ->set_time_zone('local')
            ->datetime(' ');
        $text =~ s{\[LAST UPDATED]}{$updated};
    }
    return $text;
}

=head2 get_email_text

Returns the agenda with the Zoom link in the text.

From the logic in get_current_agenda, if the meeting date is in the past
then it just returns the standing template.

=cut

sub get_email_text {
    my ($class) = @_;
    my $row  = $class->get_current_agenda();
    my $tmpl = $class->get_template_row();
    my $text = $row ? $row->agenda_text : ($tmpl ? $tmpl->agenda_text : '');
    my $zoom = $tmpl ? $tmpl->zoom_url : '';
    $text =~ s{\[ZOOM LINK\]}{$zoom}g;
    if ($row) {
        if (my $meeting_date = $row->meeting_date->ymd) {
            $text =~ s{\[MEETING DATE\]}{$meeting_date}g;
        }
        if (my $draft_minutes_url = $row->draft_minutes_url) {
            $text =~ s{\[DRAFT MINUTES URL\]}{$draft_minutes_url}g;
        }
        # it starts out in the "floating" time_zone, so we have to start it at
        # UTC before converting
        my $updated = $row->modified_ts
            ->set_time_zone('UTC')
            ->set_time_zone('local')
            ->datetime(' ');
        $text =~ s{\[LAST UPDATED]}{$updated};
    }
    return $text;
}

1;
