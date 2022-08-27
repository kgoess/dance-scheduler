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
        my $login_cookie = $self->cookie("LoginMethod");
        if (!$login_cookie){
            return $self->send_error('Not logged in', 401);
        }
        my $login_method = $login_cookie->value;
        given ($login_method) {
            when ('google'){
                my $google_token = $self->cookie("GoogleToken");
                my ($res, $err) = bacds::Scheduler::FederatedAuth->check_google_auth($google_token);
                if ($err){
                    #Failed to sign in
                    my ($code, $msg) = @$err;
                    return $self->send_error($msg, $code); 
                }
                my $email = $res->{email};
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
