package bacds::Scheduler::Plugin::Auth;
use warnings;
use 5.16.0;

use Dancer2::Plugin;

register can_edit_event => sub {
    my ($dsl, $route_sub, @args) = plugin_args(@_);
    #do something

    #on failure
    #return pass;

    #on success
    return $route_sub->($dsl, @args);
};

register_plugin for_versions => [2];
