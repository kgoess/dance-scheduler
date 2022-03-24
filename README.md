BACDS dance schedule manager
----

Development and Installation
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
         bacds::Scheduler::Schema \
         'dbi:mysql:dbname=schedule' \
         scheduler \
         $(cat ~/.mysql-password)

the command for running dancer 
    plackup bin/app.psgi
