#!/usr/bin/env perl

use 5.16.0;
use warnings;

use DateTime;
use Getopt::Long;
use Pod::Usage;
use Scalar::Util qw/looks_like_number/;
use Template;

use bacds::Scheduler::Model::DanceFinder;
use bacds::Scheduler::Util::Time qw/get_today/;
use bacds::Scheduler::Util::Db qw/get_dbh/;


my ($days, @style, $basedir, $verbose, $help);
GetOptions (
    'days=i'         => \$days,
    'style=s'        => \@style,
    'b|basedir=s'    => \$basedir,
    "h|help"         => \$help,
    "verbose|debug"  => \$verbose,
);

pod2usage(1) if $help;

my $end_date;
if ($days) {
    looks_like_number($days) or pod2usage(1);
    $end_date = get_today()->add(days => $days)->ymd;
}

$basedir ||= '/var/www/bacds.org/dance-scheduler';


# need to translate the style names to style_ids
my $dbh = get_dbh(dbix_debug => $verbose);
my @style_ids;
if (@style) {
    foreach my $style_name (@style) {
        my $style = $dbh->resultset('Style')->search({
            is_deleted => 0,
            name => $style_name,
        })->first;
        $style or die "Sorry, there's no '$style_name' in the styles table";
        push @style_ids, $style->style_id;
    }
}

my $rs = bacds::Scheduler::Model::DanceFinder->search_events(
    end_date   => $end_date,
    style      => \@style_ids,
    dbix_debug => $verbose,
);
my @events = $rs->all;
say "found ".scalar(@events)." events" if $verbose;

my $tt = Template->new(
    INCLUDE_PATH => "$basedir/views",
    # these are duplicated from config.yml?
    START_TAG => '<%',
    END_TAG   => '%>',
);

$tt->process('dancefinder/listings.tt' => {
    events => \@events,
}) || die $tt->error;


__END__
=head1 NAME

dancefinder.pl - the dbix version of the dancefinder

=head1 SYNOPSIS

Generates the today.html, 18-day.html, specialevents.html files for
the front page, via cron.

Usage: dancefinder.pl [options]

 Options:
   --days        number of days to search 
   --style       (multiple allowed) e.g. CAMP
   -b|--basedir  defaults to /var/www/bacds.org/dance-scheduler
   -v|--verbose 
   -h|--help     this help message


From cron, in public_html/:

  dancefinder.pl --days 0 > tonight.html
  dancefinder.pl --days 18 > 18day.html
  dancefinder.pl --style CAMP --style SPECIAL > specialevents.html

