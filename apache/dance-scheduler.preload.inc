# This file is installed into /etc/httpd/conf.d/ via 'make httpd-conf-install'
# from the dance-scheduler dancer2 app
# and referenced from 010-www.bacds.org.conf via
#
#      Include conf.d/dance-scheduler.preload.inc
#
# See also dance-scheduler.location.inc, but this one needs to go *outside* the
# vhost block
#
# https://github.com/kgoess/dance-scheduler

# preload the app for performance
PerlSwitches -I/var/lib/dance-scheduler/lib/perl5
PerlSetEnv DANCER_CONFDIR /var/www/bacds.org/dance-scheduler
PerlSetEnv DANCER_ENVIRONMENT production
PerlSetEnv DANCER_VIEWS /var/www/bacds.org/dance-scheduler/views
PerlSetEnv DANCER_ENVDIR /var/www/bacds.org/dance-scheduler/environments
PerlSetEnv DANCER_PUBLIC /var/www/bacds.org/dance-scheduler/public
PerlSetEnv DANCER_CONFIG_EXT yml
PerlLoadModule bacds::Scheduler

