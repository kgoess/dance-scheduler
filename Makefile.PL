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
    PL_FILES            => {},
    PREREQ_PM => {
        'Class::Accessor::Lite' => 0,
        'Clone' => 0,
        'DateTime::Format::MySQL' => 0,
        'DateTime::Format::SQLite' => 0,
        'DBD::mysql' => 0,
        'DBD::mysql' => 0,
        'DBI' => 0,
        'DBIx::Class' => 0,
        'DBIx::Class::Schema::Loader' => 0,
        'Dancer2'     => 0.400000,
        'Data::Dump' => 0,
        'DateTime' => 0,
        'HTML::Entities' => 0,
        'HTTP::Date' => 0,
        'JSON::MaybeXS' => 0,
        'SQL::Translator' => 0,
        'Template' => 0,
        'Test::More' => 0,
        'Type::Library' => 0,
        'URL::Encode' => 0,
        'WWW::Form::UrlEncoded' => 0,
        'YAML'       => 0,
        'YAML::XS'       => 0,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'bacds-Scheduler-*' },
);
