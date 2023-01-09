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

        $route_sub->(@args);
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
            return $route_sub->(@args);
        } else {
            my $results = bacds::Scheduler::Util::Results->new;

            $results->add_error(40302, "You do not have permission to do that");
            $results->data(
                {
                    #url => $plugin->get_login_page_url($self),
                }
            );
            $self->response->status(403);
            $self->response->headers->content_type('application/json');
            $self->response->content($results->format);
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
        $route_sub->(@args);
    };
};


=head2 can_edit_event

Redirects to signin page if not logged-in.

The user must be signed in and be linked to either the series or
the event.

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
            return $route_sub->(@args);
        }

        my $event_id = $self->app->request->param('event_id')
            or die "missing event_id in call to can_edit_event\n";
        my $event = $dbh->resultset('Event')->find($event_id)
            or die "no event found for event_id '$event_id' in can_edit_event\n";
        my $series_id = $event->series_id;
        my @series_rs = $programmer->series(
             { 'series.series_id' => $series_id }
        );
        my @event_rs = $programmer->events(
             {  'event.event_id' => $event_id }
        );
        if (@series_rs or @event_rs) {
            $route_sub->(@args); # this is success
        } else {
            my $results = bacds::Scheduler::Util::Results->new;

            $results->add_error(40301, "You do not have permission to modify this event");
            $results->data(
                {
                    #url => $plugin->get_login_page_url($self),
                }
            );
            $self->response->status(403);
            $self->response->headers->content_type('application/json');
            $self->response->content($results->format);
        }
    };
};


=head2 can_create_event

Redirects to signin page if not logged-in.

The user must be logged in, the event must have a series_id, and the programmer must be linked to the series.

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
            return $route_sub->(@args);
        }

        my $series_id = $self->app->request->param('series_id');
        my @series_rs = $programmer->series(
             { 'series.series_id' => $series_id }
        );
        if (@series_rs ) {
            $route_sub->(@args); # this is success
        } else {
            my $results = bacds::Scheduler::Util::Results->new;

            $results->add_error(40303, "You do not have permission to create this event");
            $results->data(
                {
                    #url => $plugin->get_login_page_url($self),
                }
            );
            $self->response->status(403);
            $self->response->headers->content_type('application/json');
            $self->response->content($results->format);
        }
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

sub get_login_page_url {
    my ($plugin, $app) = @_;
    return $app->request->uri_base . "/signin.html";
}

1;
