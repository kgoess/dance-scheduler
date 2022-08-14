BACDS dance schedule manager
----

The sources for all this can be found in github https://github.com/kgoess/dance-scheduler

See that for documentation and schemas and more goodies.

Development
----


Any perl libs not available to centos-7 are in /var/lib/dance-scheduler,
so you'll want to run this before doing any dev

    eval $(perl -Mlocal::lib=/var/lib/dance-scheduler)

After running that 'eval', new modules get installed there via cpanm, e.g.
"cpanm DBIx::Class"

The files in lib/bacds/Scheduler/Schema\* were generated via

    dbicdump -o dump_directory=./lib \
         -o components='["InflateColumn::DateTime"]' \
         -o debug=1 \
         -o skip_load_external=1 \
         bacds::Scheduler::Schema \
         'dbi:mysql:dbname=schedule' \
         scheduler \
         $(cat ~/.mysql-password)

the command for running dancer 
    plackup bin/app.psgi

Unit Tests: FIXME

How To Make Schema Changes
----

FIXME


Install
----

    perl Makefile.PL
    make
    make test

    # install the libraries to /var/lib/dance-scheduler
    make install

    # install the rest of the dancer2 app to /var/www/bacds.org/dance-scheduler
    make app-install

    # optional, the only one that requires sudo
    # install the dance-scheduler.conf to /etc/httpd/conf.d/
    sudo make httpd-conf-install

    sudo service httpd restart

(Those last two, "make app-install" and "make httpd-conf-install/" will be
replaced by rpm .spec files eventually. Keeping it this way for now so that we
can iterate more easily during development.)
