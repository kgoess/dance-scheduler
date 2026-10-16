#!/usr/bin/env -S perl -CA

use 5.32.1;
use warnings;

# local::lib is a no-op if already loaded
use local::lib '/var/lib/dance-scheduler';

use Email::Stuffer;
use File::Temp;
use Getopt::Long;
use Pod::Usage;

use bacds::Scheduler::Model::FormQueue;

my ($to, $form, $dry_run, $verbose, $help);
GetOptions(
    'to=s'      => \$to,
    'form=s'    => \$form,
    'dry-run'   => \$dry_run,
    'verbose|v' => \$verbose,
    'help|h'    => \$help,
) or pod2usage(2);
pod2usage(-verbose => 2) if $help;
pod2usage("--to is required\n") unless $to;

my $queue   = bacds::Scheduler::Model::FormQueue->new(form => $form);
my $pending = $queue->pending;

if (!@$pending) {
    say 'No requests are waiting for review.' if $verbose;
    exit 0;
}

my $count   = @$pending;
my $s       = $count == 1 ? '' : 's';
my $subject = "BACDS: $count membership addition request$s waiting for review";
my $command = '/var/lib/dance-scheduler/bin/civicrm-form-queue.pl';
my $form_name = $queue->form;

my $body = join "\n",
    "$count request$s to add someone to a membership "
        .($count == 1 ? 'is' : 'are')." waiting in CiviCRM.",
    '',
    map({ $queue->format_request($_) } @$pending),
    'To approve or reject, on the bacds.org server run (as root):',
    '',
    map({ ("  $command approve $_->{id}", "  $command reject $_->{id}") } @$pending),
    '',
    "or use CiviCRM's submissions page, once it works on our PHP version:",
    "https://bacds.civicrm.org/civicrm/admin/afform/submissions?name=$form_name",
    '',
    "This email is sent every morning while requests are waiting.",
    '';

my $stuffer = Email::Stuffer
    ->from     ('BACDS noreply <noreply@bacds.org>')
    ->to       ($to)
    ->subject  ($subject)
    ->text_body($body)
;

if ($dry_run) {
    my $temp_fh = File::Temp->new(UNLINK => 0);
    $stuffer->transport('Print', fh => $temp_fh);
    say "dry-run, email written to $temp_fh";
}

$stuffer->send or die "sending email failed but that's all I know";
say(($dry_run ? 'Would send: ' : 'Sent: ') . $subject) if $verbose;

__END__

=head1 NAME

civicrm-check-form-queue.pl - Email a summary of membership addition requests waiting for review

=head1 SYNOPSIS

    civicrm-check-form-queue.pl --to someone@example.com

    Options:
        --to ADDRESS   who to email (required)
        --form NAME    a different FormBuilder form (default
                       afformAddSomeoneToYourMembership)
        --dry-run      write the email to a temp file instead of sending it
        --verbose, -v  say what happened
        --help, -h     full help

=head1 DESCRIPTION

Checks CiviCRM for "Add someone to your membership" requests waiting for
review and, if there are any, emails a summary with the commands to approve
or reject each one (see civicrm-form-queue.pl). Sends nothing when the
queue is empty. Meant to run from cron once a day; see
cron/civicrm-check-form-queue.

=cut
