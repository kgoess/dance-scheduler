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

    $app->redirect('/signin.html' => 303);
}

sub login_redirect_json {
    my ($plugin, $app) = @_;

    # this 401 will trigger this in the js app:
    #     alert("You don't have authorization to do that!");
    $app->response->status(401);
    # FIXME how to send back the /signin.html location?
}

=head2 can_edit_event

=cut

plugin_keywords can_edit_event => sub {
    my ($plugin, $route_sub, @args) = @_;
    return sub {
        my ($self) = @_;

        my $email = $self->app->request->var('signed_in_as')
            or return $plugin->login_redirect_json($self);
        #do something

        #on failure
        #return pass;

        #on success
        $route_sub->(@args);
    };
};

1;
