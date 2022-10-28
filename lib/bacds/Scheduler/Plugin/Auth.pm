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

Checks for "signed_in_as" in the request stash and redirects if not present.

=cut


plugin_keywords requires_login => sub {
    my ($plugin, $route_sub, @args) = @_;
    return sub {
        my ($self) = @_;

        my $login = $self->app->request->var('signed_in_as');

        if (!$login) {

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

        $route_sub->(@args);
    };
};

sub login_redirect_html {
    my ($plugin, $app) = @_;

    $app->redirect($plugin->get_login_page_url($app) => 303);
}

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
    # FIXME how to send back the /signin.html location?
}

sub get_login_page_url {
    my ($plugin, $app) = @_;
    return $app->request->uri_base . "/signin.html";
}


=head2 can_edit_event

=cut

plugin_keywords can_edit_event => sub {
    my ($plugin, $route_sub, @args) = @_;
    return sub {
        my ($self) = @_;
        my $email = $self->app->request->var('signed_in_as')
            or return $plugin->login_redirect_json($self);

        my $dbh = get_dbh();

        my @rs = $dbh->resultset('Programmer')->search({
            email => $email,
        });
        my $programmer = $rs[0];

        my $event_id = $self->app->request->param('event_id');
        my $event_rs = $dbh->resultset('Event')->find($event_id);
        my $series_id = $event_rs->series_id;
        my @series_rs = $programmer->series(
             #{ 'series.series_id' => $series_id }
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

1;
