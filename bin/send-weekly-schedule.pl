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


my ($days, $to, $basedir, $db, $dbuser, $approved, $dry_run, $verbose, $help);
GetOptions (
    'days=i'           => \$days,
    'to=s'             => \$to,
    'b|basedir=s'      => \$basedir,
    'db=s'             => \$db,
    'dbuser=s'         => \$dbuser,
    'approved'         => \$approved,
    'dry-run'          => \$dry_run,
    "h|help"           => \$help,
    "verbose|debug"    => \$verbose,
);

pod2usage(1) if $help;

$to       ||= 'bacds-announce@bacds.org';
$days     ||= 8;
$db       ||= 'schedule';
$dbuser   ||= 'scheduler';
$basedir  ||= '/var/www/bacds.org/dance-scheduler';
$approved ||= '/var/lib/send-weekly-schedule/approved';

looks_like_number($days) or pod2usage(1);
my $end_date = get_today()->add(days => $days)->ymd;

open my $fh, "<", $approved or die "can't read $approved: $!";
my $moderator_pw = <$fh>;
close $fh;
chomp $moderator_pw;
$moderator_pw or die "couldn't get value from $approved";

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

my $today_str = DateTime->now->strftime("%a., %b. %e");

my ($html_part, $text_part);
$tt->process('send-weekly-schedule/html.tt' => {
    events => \@events,
    highlight_special_types => 1,
    today_str => $today_str,
}, \$html_part) || die $tt->error;

$tt->process('send-weekly-schedule/text.tt' => {
    events => \@events,
    highlight_special_types => 1,
    today_str => $today_str,
}, \$text_part) || die $tt->error;


my $temp_fh = File::Temp->new(
    $dry_run ? ( UNLINK => 0 ) : (),
);

#   ->bcc      ('bunbun@sluggy.com')
my $stuffer = Email::Stuffer
    ->from       ('BACDS noreply <noreply@bacds.org>')
    ->to         ($to)
    ->subject    ("Dances for the week of $today_str")
    ->header     (Approved => $moderator_pw)
    ->text_body  ($text_part)
    ->html_body  ($html_part);


if ($dry_run) {
    $stuffer->transport  ('Print', fh => $temp_fh );
    say "dry-run, email written to $temp_fh";
} else {
    $stuffer->send or die "sending email failed but that's all I know";
}

say $stuffer->as_string if ($verbose);


__END__
=head1 NAME

send-weekly-schedule.pl - cron script for weekly email blast

=head1 SYNOPSIS

Generates HTML and text parts for an email to bacds-announce. Injects the mail
directly into the mail queue.

Usage: send-weekly-schedule.pl [options]

 Options:
   --send-via mailman or smtp, defaults to mailman
   --days     number of days to search, defaults to 8
   --to       mailman list, defaults to bacds-announce
   --db       (defaults to "schedule", is if you want "schedule_test")
   --dbuser   (defaults to "scheduler", is if you want "scheduler_test")
   --dry-run  don't send, just write file and exit
   --approved path to file with list moderator password, defaults
              to /var/lib/send-weekly-schedule/approved (file permissions
              should be tightly restricted to the user running this as cron,
              probably root)

   -b|--basedir  defaults to /var/www/bacds.org/dance-scheduler
   -v|--verbose
   -h|--help     this help message

Is meant to be run from cron.
