package bacds::Scheduler::Plugin::Auth;
use warnings;
use 5.16.0;

use Dancer2::Plugin;
use Data::Dump qw/dump/;
use bacds::Scheduler::FederatedAuth;

plugin_keywords can_edit_event => sub {
    my ($plugin, $route_sub, @args) = @_;
    return sub {
        my ($self) = @_;

        my $login_cookie = $self->cookie("LoginMethod")
            or return $self->send_error('Not logged in', 401);

        my $login_method = $login_cookie->value;

        given ($login_method) {
            when ('google') {
                my $google_token = $self->cookie("GoogleToken")
                    or return $self->send_error('Missing GoogleToken cookie', 400);
                my ($res, $err) = bacds::Scheduler::FederatedAuth
                    ->check_google_auth($google_token);
                if ($err) {
                    #Failed to sign in
                    my ($code, $msg) = @$err;
                    warn qq{check_google_auth: "$msg" for token '$google_token"};
                    return $self->send_error('check google auth failure, see server logs', $code);
                }
                my $email = $res->{email};
            }
            when ('facebook') {
                ...
            }
            when ('session') {
                my $session_cookie = $self->cookie("LoginSession")
                    or return $self->send_error('Missing LoginSession cookie', 400);
                my ($programmer) = bacds::Scheduler::FederatedAuth
                    ->check_session_cookie($session_cookie)
                     or return $self->send_error('login failed', 401);

            }
        }
        #do something

        #on failure
        #return pass;

        #on success
        $route_sub->(@args);
    };
};

1;
