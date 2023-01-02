=head1 NAME

bacds::Scheduler::Plugin::AccordionConfig - drives the dance-scheduler web UI

=head1 SYNOPSIS

=head1 DESCRIPTION

The dance-scheduler web UI is set up with "accordion folds", where events,
venues, callers, etc. are each in their own accordion fold.

Those individual accordion folds are all driven through views/accordion.tt, and
the configuration that drives that template is a YAML file, accordions-webui.yml, that
lives in the root directory of the git workspace, or the application directory
in production: /var/www/bacds.org/dance-scheduler

=cut

package bacds::Scheduler::Plugin::AccordionConfig;

use 5.16.0;
use warnings;

use Dancer2::Plugin;
use YAML qw/LoadFile/;

has config => (
    is => 'rwp',
);

has filename => (
    is => 'ro',
    default => 'accordions-webui.yml',
);

plugin_keywords 'preload_accordion_config', 'get_accordion_config';

sub preload_accordion_config {
    my ($plugin) = @_;

    my $base_dir = $plugin->app->config->{appdir};

    my $path = join '/', $base_dir, $plugin->filename;

    my $config = LoadFile($path);

    $plugin->_set_config($config);
}

sub get_accordion_config {
    my ($plugin) = @_;

    return $plugin->config;
}

1;
