=head1 NAME

=encoding utf8

bacds::Scheduler::Plugin::Checksum - adds checksum validation keywords to the dancer2 DSL

=head1 SYNOPSIS

In bacds::Scheduler:

    use bacds::Scheduler::Plugin::Checksum;

    post '/band/' => requires_checksum sub {
                       ↑   ↑   ↑
        ...etc...
    }

=head1 DESCRIPTION

This uses the Dancer2 plumbing to set up some DSL keywords
that we can attach to the routes in Scheduler.pm This is intended to allow us
to force users to reload if we've changed the js/css on the server.

=head1 KEYWORDS

=cut

package bacds::Scheduler::Plugin::Checksum;

use 5.16.0;
use warnings;

use Dancer2::Plugin;
use Data::Dump qw/dump/;

use bacds::Scheduler::Util::Initialize;
use bacds::Scheduler::Util::Results;

my $Results_Class = "bacds::Scheduler::Util::Results";

=head2 requires_checksum

Checks that the current checksum matches the on in the request
=cut

plugin_keywords requires_checksum => sub {
    my ($plugin, $route_sub, @args) = @_;
    return sub {
        my ($self) = @_;
        my $checksum = $self->app->cookie('Checksum');
        if ( 
            $checksum->value ne bacds::Scheduler::Util::Initialize::get_checksum() 
        ){
            $self->app->response->status(426);
            my $results = $Results_Class->new;
            $results->add_error(426, 
                "You need to reload the page to be able to complete your request"
            );
            $self->app->response->halt($results->format);
        }

        return $route_sub->($self, @args);
    };
};

1;
