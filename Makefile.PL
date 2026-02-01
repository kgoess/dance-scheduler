use strict;
use warnings;
use ExtUtils::MakeMaker;

# Normalize version strings like 6.30_02 to 6.3002,
# so that we can do numerical comparisons on it.
my $eumm_version = $ExtUtils::MakeMaker::VERSION;
$eumm_version =~ s/_//;

WriteMakefile(
    NAME                => 'bacds::Scheduler',
    AUTHOR              => q{YOUR NAME <youremail@example.com>},
    VERSION_FROM        => 'lib/bacds/Scheduler.pm',
    ABSTRACT            => 'YOUR APPLICATION ABSTRACT',
    ($eumm_version >= 6.3001
      ? ('LICENSE'=> 'perl')
      : ()),
    EXE_FILES => [
        'bin/dance-scheduler-user-password.pl',
        'bin/dance-scheduler-add-programmer.pl',
        'bin/dancefinder.pl',
        'bin/send-weekly-schedule.pl',
        'bin/tonightheader.pl',
    ],
    PL_FILES            => {},
    BUILD_REQUIRES => {
        'Test::WWW::Mechanize::PSGI' => 0,
        'LWP::ConsoleLogger::Easy' => 0,
    },
    PREREQ_PM => {
        'Class::Accessor::Lite' => 0,
        'Clone' => 0,
        'Crypt::Bcrypt' => 0,
        'Crypt::Blowfish' => 0,
        'Crypt::CBC' => 0,
        'Crypt::JWT' => 0,
        'Data::UUID' => 0,
        'Date::Calc' => 0,
        'DateTime::Format::MySQL' => 0,
        'DateTime::Format::SQLite' => 0,
        'DateTime::Format::ISO8601' => 0,
        'DBD::MariaDB' => 0,
        'DBI' => 0,
        'DBIx::Class' => 0,
        'DBIx::Class::Schema::Loader' => 0,
        'DBIx::Class::Storage::DBI::MariaDB' => 0,
        'Dancer2' => 0.400000,
        'Dancer2::Plugin::HTTP::ContentNegotiation' => 0,
        'Dancer2::Plugin::ParamTypes' => 0,
        'Data::Dump' => 0,
        'Data::Entropy::Algorithms' => 0,
        'Data::ICal' => 0,
        'DateTime' => 0,
        'Digest::Bcrypt' => 0,
        'Email::Stuffer' => 0,
        'Facebook::OpenGraph' => 0,
        'HTML::Entities' => 0,
        'HTTP::Date' => 0,
        'HTTP::Negotiate' => 0,
        'Cpanel::JSON::XS' => 0,
        'LWP::Protocol::https' => 0,
        'String::Random' => 0,
        'SQL::Translator' => 0,
        'Switch::Plain' => 0,
        'Template' => 0,
        'Template::Plugin::POSIX' => 0,
        'Text::Markdown' => 0,
        'Test::More' => 0,
        'Type::Library' => 0,
        'URL::Encode' => 0,
        'WWW::Form::UrlEncoded' => 0,
        'YAML' => 0,
        'YAML::XS' => 0,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'bacds-Scheduler-*' },
);

# this should eventually go into the rpm .spec file, but doing it this way will
# let us iterate on it faster
sub MY::postamble {
    return <<'MAKE_FRAG';

# install the .psgi and other dancer2 supporting files

APPDIR=/var/www/bacds.org/dance-scheduler

app-install:
	@if [ -n "$$(find * -name '*.sw?')" ] ; then echo -e "\n*****************\n*** Please exit vim and make sure there aren't any *.sw? files in the installation tree. ***\n*******************\n" ; false; fi
	install -d $(APPDIR) --mode 2775 --group dev
	install bin/app.psgi $(APPDIR)
	install config.yml   $(APPDIR)
	install accordions-webui.yml   $(APPDIR)
	install README.md    $(APPDIR)
	install -d $(APPDIR)/environments  --mode 2775 --group dev
	install -d $(APPDIR)/views         --mode 2775 --group dev
	install -d $(APPDIR)/views/layouts --mode 2775 --group dev
	install -d $(APPDIR)/public        --mode 2775 --group dev
	install -d $(APPDIR)/public/images --mode 2775 --group dev
	install -d $(APPDIR)/public/js     --mode 2775 --group dev
	install -d $(APPDIR)/public/css    --mode 2775 --group dev
	install -d $(APPDIR)/private       --mode 2770 --group apache
	cp -r environments   $(APPDIR)
	cp -r views          $(APPDIR)
	cp -r public         $(APPDIR)
	@if [ ! -e $(APPDIR)/private/mysql-password ]; then \
	    echo -e "\n***************"; \
	    echo "Please put the mysql password into $(APPDIR)/private/mysql-password"; \
	    echo "and chown apache.apache, chmod 440."; \
	    echo -e "***************\n"; \
	    false; \
	fi

# the httpd.conf requires sudo, so keeping it separate (it won't change often)
httpd-conf-install:
	@if [ ! $$(id -u) = 0 ]; then echo -e "\n*****************\n*** You need to run this with sudo: 'sudo make httpd-conf-install'***\n*******************\n" ; false; fi
	install apache/dance-scheduler.conf /etc/httpd/conf.d/dance-scheduler.conf
	@echo -e "\n*****************\n*** Done! Now do 'sudo service httpd restart'***\n*******************\n"

# ditto for cron-install
cron-install:
	@if [ ! $$(id -u) = 0 ]; then  echo -e "\n*****************\n*** You need to run this with sudo: 'sudo make cron-install'***\n*******************\n" ; false; fi
	install cron/dance-scheduler-backup /etc/cron.daily/dance-scheduler-backup
	install cron/send-weekly-schedule /etc/cron.d/send-weekly-schedule

MAKE_FRAG
}

