=head1 NAME

=encoding utf8

bacds::Scheduler::Plugin::Auth - adds auth keywords to the dancer2 DSL

=head1 SYNOPSIS

In bacds::Scheduler:

    use bacds::Scheduler::Plugin::Auth;

    post '/band/' => requires_login sub {
                       ↑   ↑   ↑
        ...etc...
    }

=head1 DESCRIPTION

This uses the Dancer2 plumbing to set up some DSL auth keywords
that we can attach to the routes in Scheduler.pm

=head1 KEYWORDS

=cut

package bacds::Scheduler::Plugin::Auth;
use warnings;
use 5.16.0;

use Dancer2::Plugin;
use Dancer2::Serializer::JSON;
use Data::Dump qw/dump/;
use Encode qw/decode_utf8/;
use HTTP::Negotiate qw/choose/;

use bacds::Scheduler::FederatedAuth;
use bacds::Scheduler::Util::Cookie qw/LoginMethod LoginSession GoogleToken/;
use bacds::Scheduler::Util::Results;
use bacds::Scheduler::Model::Event;
use bacds::Scheduler::Util::Db qw/get_dbh/;

=head2 requires_login

Checks for "signed_in_as" in the request stash and redirects if not
present.

=cut

plugin_keywords requires_login => sub {
    my ($plugin, $route_sub, @args) = @_;
    return sub {
        my ($self) = @_;

        $self->app->request->var('signed_in_as') 
            or return $plugin->login_redirect($self);

        $route_sub->($self, @args);
    };
};

=head2 requires_superuser

Redirects to signin page if not logged-in.

Checks that the logged-in user has Programmers.is_superuser set in
the database.

On failure this will just show a popup with "You do not have
permission to do that".

=cut

plugin_keywords requires_superuser => sub {
    my ($plugin, $route_sub, @args) = @_;
    return sub {
        my ($self) = @_;
        my $programmer = $self->app->request->var('signed_in_as')
            or return $plugin->login_redirect($self);

        if ($programmer->is_superuser) {
            return $route_sub->($self, @args);
        } else {
            return $plugin->json_error($self, 403, 40302,
                "You do not have permission to do that");
        }
        
    };
};

=head2 requires_nothing

Just exists to make the YAML-ized route construction in Scheduler.pm simpler.

=cut

plugin_keywords requires_nothing => sub {
    my ($plugin, $route_sub, @args) = @_;
    return sub {
        my ($self) = @_;
        $route_sub->($self, @args);
    };
};


=head2 can_edit_event

Redirects to signin page if not logged-in.

The user must be signed in and be linked to the event's series, the event
itself, or one of the event's teams.

The edit can't attach the event to a series or team the user isn't linked
to, and only a superuser can take an event out of its series (see
L</check_series_and_teams>).

An is_superuser user can always edit the event.

On failure this will just show a popup with "You do not have
permission to do that".

=cut

plugin_keywords can_edit_event => sub {
    my ($plugin, $route_sub, @args) = @_;
    return sub {
        my ($self) = @_;
        my $programmer = $self->app->request->var('signed_in_as')
            or return $plugin->login_redirect($self);

        my $dbh = get_dbh();

        if ($programmer->is_superuser) {
            return $route_sub->($self, @args);
        }

        my $event_id = $self->app->request->param('event_id')
            or return $plugin->json_error($self, 400, 40001,
                "Missing event_id");
        my $event = $dbh->resultset('Event')->find($event_id)
            or return $plugin->json_error($self, 404, 40401,
                "There's no event $event_id");
        my $series_id = $event->series_id;
        my @series_rs = $programmer->series(
             { 'series.series_id' => $series_id }
        );
        my @event_rs = $programmer->events(
             {  'event.event_id' => $event_id }
        );
        my @event_teams_rs = $event->teams();
        my @teams_rs = $programmer->teams(
             {'team.team_id' => [map $_->team_id, @event_teams_rs]}
        );
        if (!(@series_rs or @event_rs or @teams_rs)) {
            return $plugin->json_error($self, 403, 40301,
                "You do not have permission to modify this event");
        }

        $plugin->check_series_and_teams($self, $programmer, $event)
            or return; # it set the error response

        return $route_sub->($self, @args); # this is success
    };
};


=head2 can_create_event

Redirects to signin page if not logged-in.

The user must be logged in, the event must have a series_id, and the programmer must be linked to the series.

Any teams on the new event must be ones the programmer is linked to, too
(see L</check_series_and_teams>).

An is_superuser user can always create an event. And they're the
only ones who can create events that aren't part of a series.

=cut

plugin_keywords can_create_event => sub {
    my ($plugin, $route_sub, @args) = @_;
    return sub {
        my ($self) = @_;
        my $programmer = $self->app->request->var('signed_in_as')
            or return $plugin->login_redirect($self);

        if ($programmer->is_superuser) {
            return $route_sub->($self, @args);
        }

        my $series_id = $self->app->request->param('series_id');
        my @series_rs = $programmer->series(
             { 'series.series_id' => $series_id }
        );
        if (!@series_rs) {
            return $plugin->json_error($self, 403, 40303,
                "You do not have permission to create this event");
        }

        $plugin->check_series_and_teams($self, $programmer, undef)
            or return; # it set the error response

        return $route_sub->($self, @args); # this is success
    };
};

=head1 HELPER METHODS

These are just used internally in this class

=head2 login_redirect

Decides whether to call login_redirect_html or *_json based on the
incoming Accept headers, using HTTP::Negotiate.

=cut

sub login_redirect{
    my ($plugin, $self) = @_;
    # see also Dancer2::Plugin::HTTP::ContentNegotiation?
    # and $self->app->request->header('Accept');
    state $variants = [
        ['html', 1.000, 'text/html'       ],
        ['json', 1.000,    'application/json'],
    ];
    my $media_type = choose($variants, $self->app->request->headers);
    if ($media_type eq 'html') {
        return $plugin->login_redirect_html($self);
    } else {
        return $plugin->login_redirect_json($self);
    }
}

=head2 login_redirect_html

Sends a 303 redirect to the login page url.

=cut

sub login_redirect_html {
    my ($plugin, $app) = @_;

    $app->redirect($plugin->get_login_page_url($app) => 303);
}

=head2 login_redirect_json

Sends a 401-Unauthorized and a blob of json data with
the login url. The js app knows how to handle that.

=cut

sub login_redirect_json {
    my ($plugin, $app, @args) = @_;
    my $results = bacds::Scheduler::Util::Results->new;

    $results->add_error(40101, "You are not logged in");
    $results->data(
        {
            url => $plugin->get_login_page_url($app),
        }
    );

    # this 401 will trigger this in the js app:
    #     alert("You don't have authorization to do that!");
    $app->response->status(401);
    $app->response->headers->content_type('application/json');
    $app->response->content($results->format);
}

=head2 check_series_and_teams($app, $programmer, $event)

For a non-superuser creating ($event undef) or editing an event, checks
what the request does to the event's series and teams:

  - a new series_id must be a series the programmer is linked to
  - an empty series_id, which takes an existing event out of its series,
    is superuser-only, like creating an event without one
  - every team_id the request adds must be a team the programmer is
    linked to; removing teams is fine

Without this, a programmer who could edit one event could move it onto
another series' page or into another team's listings.

A series_id that isn't in the request is left alone by
Model->put_row, so isn't checked. A missing team_id means "no teams"
to put_row, so it's treated that way here too.

Returns true if it's all allowed, otherwise sets a 403 JSON response and
returns false.

=cut

sub check_series_and_teams {
    my ($plugin, $app, $programmer, $event) = @_;

    my $params = $app->request->parameters;

    # the form sends "" for an empty select, and "NULL" for some disabled
    # inputs
    my $clean = sub {
        my %seen;
        return grep { defined && length && $_ ne 'NULL' && !$seen{$_}++ } @_;
    };

    if ($event && defined $params->get('series_id')) {
        my ($new_series_id) = $clean->($params->get_all('series_id'));
        my $old_series_id   = $event->series_id;

        if (($new_series_id // '') ne ($old_series_id // '')) {
            if (!defined $new_series_id) {
                $plugin->json_error($app, 403, 40304,
                    "Only a superuser can take an event out of its series");
                return 0;
            }
            my @linked = $programmer->series({ 'series.series_id' => $new_series_id });
            if (!@linked) {
                $plugin->json_error($app, 403, 40305,
                    "You can't move an event into a series you're not linked to");
                return 0;
            }
        }
    }

    my %old_team = map { $_->team_id => 1 } ($event ? $event->teams : ());
    my @added_team_ids = grep { !$old_team{$_} } $clean->($params->get_all('team_id'));
    if (@added_team_ids) {
        my %linked = map { $_->team_id => 1 }
            $programmer->teams({ 'team.team_id' => \@added_team_ids });
        if (my @not_linked = grep { !$linked{$_} } @added_team_ids) {
            my @names = map { $_->name }
                get_dbh()->resultset('Team')->search(
                    { team_id => \@not_linked }, { order_by => 'name' },
                );
            @names = @not_linked unless @names;
            $plugin->json_error($app, 403, 40306,
                "You can't add a team you're not linked to: " . join(', ', @names));
            return 0;
        }
    }

    return 1;
}

=head2 json_error

Sets the response to a JSON error in the bacds::Scheduler::Util::Results
format, with the given HTTP status, error number and message.

=cut

sub json_error {
    my ($plugin, $app, $status, $num, $msg) = @_;

    my $results = bacds::Scheduler::Util::Results->new;
    $results->add_error($num, $msg);
    $results->data({});

    $app->response->status($status);
    $app->response->headers->content_type('application/json');
    $app->response->content($results->format);
}

sub get_login_page_url {
    my ($plugin, $app) = @_;
    return $app->request->uri_base . "/signin.html";
}

1;
