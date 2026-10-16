# This file is installed into /etc/httpd/conf.d/ via 'make httpd-conf-install'
# from the dance-scheduler dancer2 app
# and referenced from 010-www.bacds.org.conf via
#       
#    Include conf.d/dance-scheduler.location.inc
#
# See also dance-scheduler.preload.inc, but this one should go *inside* the
# vhost block to limit /dance-scheduler to just the www.bacds.org vhost
#
# https://github.com/kgoess/dance-scheduler

<Location /dance-scheduler>
  SetHandler perl-script
  PerlHandler Plack::Handler::Apache2
  PerlSetVar psgi_app /var/www/bacds.org/dance-scheduler/app.psgi
</Location>

