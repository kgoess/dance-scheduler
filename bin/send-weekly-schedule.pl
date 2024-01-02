#!/usr/bin/env perl

use 5.16.0;
use warnings;

# local::lib is a no-op if already loaded
use local::lib '/var/lib/dance-scheduler';

use Email::Stuffer;
use File::Temp;
use Getopt::Long;
use Pod::Usage;
use Scalar::Util qw/looks_like_number/;
use Template;


use bacds::Scheduler::Model::DanceFinder;
use bacds::Scheduler::Util::Time qw/get_today/;
use bacds::Scheduler::Util::Db qw/get_dbh/;


my ($send_via, $days, $to, $basedir, $db, $dbuser, $dry_run, $verbose, $help);
GetOptions (
    'send-via=s'       => \$send_via,
    'days=i'           => \$days,
    'to=s'             => \$to,
    'b|basedir=s'      => \$basedir,
    'db=s'             => \$db,
    'dbuser=s'         => \$dbuser,
    'dry-run'          => \$dry_run,
    "h|help"           => \$help,
    "verbose|debug"    => \$verbose,
);

pod2usage(1) if $help;

$send_via ||= 'mailman';
$to       ||= 'bacds-announce@bacds.org';
$days     ||= 7;
$db       ||= 'schedule';
$dbuser   ||= 'scheduler';
$basedir  ||= '/var/www/bacds.org/dance-scheduler';

$send_via =~ /^(mailman|smtp)$/ or pod2usage("ERROR: --send_via should be mailman|smtp not '$send_via'");

looks_like_number($days) or pod2usage(1);
my $end_date = get_today()->add(days => $days)->ymd;

my $rs = bacds::Scheduler::Model::DanceFinder->search_events(
    end_date   => $end_date,
    dbix_debug => $verbose,
    db         => $db,
    dbuser     => $dbuser
);
my @events = $rs->all;

my $tt = Template->new(
    INCLUDE_PATH => "$basedir/views",
    # these are duplicated from config.yml?
    START_TAG => '<%',
    END_TAG   => '%>',
);

binmode( STDOUT, ":utf8" );

my ($html_part, $text_part);
$tt->process('dancefinder/listings.tt' => {
    events => \@events,
    highlight_special_types => 1,
}, \$html_part) || die $tt->error;

$tt->process('dancefinder/listings-text.tt' => {
    events => \@events,
    highlight_special_types => 1,
}, \$text_part) || die $tt->error;


my $temp_fh = File::Temp->new(
    $dry_run ? ( UNLINK => 0 ) : (),
);

#   ->bcc      ('bunbun@sluggy.com')
my $stuffer = Email::Stuffer
    ->from       ('BACDS noreply <noreply@bacds.org>')
    ->to         ($to)
    ->subject    ("Dances for the week of ".DateTime->now->strftime("%a., %b. %e"))
    ->text_body  ($text_part)
    ->html_body  ($html_part);


if ($send_via eq 'mailman') {
    say "sending via mailman" if $verbose;
    $stuffer->transport  ('Print', fh => $temp_fh );
    if ($dry_run) {
        say "email written to $temp_fh";
    }
    die "mailman not implemented yet";
}

if ($dry_run) {
    say "--dry-run set, not sending anything anywhere";
} else {
    $stuffer->send or die "sending email failed but that's all I know";
}

say $stuffer->as_string if ($verbose);


`cat $temp_fh`;

__END__
=head1 NAME

send-weekly-schedule.pl - cron script for weekly email blast

=head1 SYNOPSIS

Generates HTML and text parts for an email to bacds-announce. Injects the mail
directly into the mail queue.

Usage: send-weekly-schedule.pl [options]

 Options:
   --send-via mailman or smtp, defaults to mailman
   --days     number of days to search, defaults to 7
   --to       mailman list, defaults to bacds-announce
   --db       (defaults to "schedule", is if you want "schedule_test")
   --dbuser   (defaults to "scheduler", is if you want "scheduler_test")
   --dry-run  don't send, just write file and exit

   -b|--basedir  defaults to /var/www/bacds.org/dance-scheduler
   -v|--verbose
   -h|--help     this help message

Is meant to be run from cron.
