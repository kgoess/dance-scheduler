#!/usr/bin/env -S perl -CA

use 5.32.1;
use warnings;

# local::lib is a no-op if already loaded
use local::lib '/var/lib/dance-scheduler';

use Data::Dump qw/dump/;
use Email::Stuffer;
use File::Temp;
use Getopt::Long;
use Pod::Usage;
use Scalar::Util qw/looks_like_number/;
use Template;

use bacds::Scheduler::Model::DanceFinder;
use bacds::Scheduler::Util::Time qw/get_today/;
use bacds::Scheduler::Util::Db qw/get_dbh/;
use bacds::Scheduler::WeeklyEmailQueue;

my ($days, $to, $html, $subject, $basedir, $data_dir, $db, $dbuser,
    $dry_run, $verbose, $help);
GetOptions (
    'days=i'           => \$days,
    'to=s'             => \$to,
    'html'             => \$html,
    'subject=s'        => \$subject,
    'b|basedir=s'      => \$basedir,
    'data-dir=s'       => \$data_dir,
    'db=s'             => \$db,
    'dbuser=s'         => \$dbuser,
    'dry-run'          => \$dry_run,
    "h|help"           => \$help,
    "verbose|debug"    => \$verbose,
);

pod2usage(1) if $help;

my $today_str = DateTime->now->strftime("%a., %b. %e");

$to       ||= 'bacds-announce@bacds.org';
$days     ||= 8;
$subject  ||= "Dances and news for the week of $today_str";
$db       ||= 'schedule';
$dbuser   ||= 'scheduler';
$basedir  ||= '/var/www/bacds.org/dance-scheduler';
$data_dir ||= '/var/lib/dance-scheduler'; # where weekly-email-queue lives

looks_like_number($days) or pod2usage(1);
my $end_date = get_today()->add(days => $days)->ymd;

my $rs = bacds::Scheduler::Model::DanceFinder->search_events(
    end_date   => $end_date,
    dbix_debug => $verbose,
    db         => $db,
    dbuser     => $dbuser
);
my @events = $rs->all;

my $q = bacds::Scheduler::WeeklyEmailQueue->new(
    basedir => $data_dir,
);
$q->init;
my (@news_html, @news_text);
while (my ($html, $text) = $q->get_next) {
    push @news_html, $html;
    push @news_text, $text;
}
    
my $tt = Template->new(
    INCLUDE_PATH => "$basedir/views",
    # these are duplicated from config.yml?
    START_TAG => '<%',
    END_TAG   => '%>',
);

my ($html_part, $text_part);
$tt->process('send-weekly-schedule/html.tt' => {
    canonical_scheme => 'https',
    canonical_host => 'bacds.org',
    events => \@events,
    news_html => \@news_html,
    highlight_special_types => 1,
    today_str => $today_str,
}, \$html_part) || die $tt->error;

$tt->process('send-weekly-schedule/text.tt' => {
    canonical_scheme => 'https',
    canonical_host => 'bacds.org',
    events => \@events,
    news_text => \@news_text,
    highlight_special_types => 1,
    today_str => $today_str,
}, \$text_part) || die $tt->error;

$text_part =~ s/<.+?>//g;


#   ->bcc      ('bunbun@sluggy.com')
my $stuffer = Email::Stuffer
    ->from       ('BACDS noreply <noreply@bacds.org>')
    ->to         ($to)
    ->subject    ($subject)
    ->text_body  ($text_part)
;

if ($html) {
    $stuffer->html_body($html_part)
}


if ($dry_run) {
    my $temp_fh = File::Temp->new(UNLINK => 0);
    $stuffer->transport  ('Print', fh => $temp_fh );
    say "dry-run, email written to $temp_fh";
}


$stuffer->send or die "sending email failed but that's all I know";

if (!$dry_run) {
    $q->mark_all_done;
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
   --days     number of days to search, defaults to 8
   --to       mailman list, defaults to bacds-announce
   --html     whether to attach an HTML part
   --subject  (defaults to "Dances for the week of $today_str")
   --db       (defaults to "schedule", is if you want "schedule_test")
   --dbuser   (defaults to "scheduler", is if you want "scheduler_test")
   --dry-run  don't send, just write file and exit
   -b|--basedir  defaults to /var/www/bacds.org/dance-scheduler
    --data-dir  defaults to /var/lib/dance-scheduler (where weekly-email-queue lives)
   -v|--verbose
   -h|--help     this help message

Is meant to be run from cron.
