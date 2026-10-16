#!/usr/bin/env -S perl -CA

use 5.32.1;
use warnings;

# local::lib is a no-op if already loaded
use local::lib '/var/lib/dance-scheduler';

use Getopt::Long;
use Pod::Usage;

use bacds::Scheduler::Model::FormQueue;

my ($form, $yes, $help);
GetOptions(
    'form=s' => \$form,
    'yes|y'  => \$yes,
    'help|h' => \$help,
) or pod2usage(2);
pod2usage(-verbose => 2) if $help;

my ($command, $id) = @ARGV;
pod2usage(2) unless $command;

my $queue = bacds::Scheduler::Model::FormQueue->new(form => $form);

if ($command eq 'list') {
    my $pending = $queue->pending;
    say 'No requests are waiting for review.' unless @$pending;
    say $queue->format_request($_) for @$pending;
}
elsif ($command eq 'show') {
    pod2usage("show needs a request number\n") unless defined $id;
    my $request = $queue->get($id);
    say $queue->format_request($request);
    require Data::Dump;
    say 'Submitted form values:';
    say Data::Dump::dump($request->{data});
}
elsif ($command eq 'approve') {
    pod2usage("approve needs a request number\n") unless defined $id;
    my $request = $queue->get($id);
    say $queue->format_request($request);
    exit 1 unless confirm("Approve request #$id?");

    my $report = $queue->approve($id);
    say "  $_" for @{ $report->{notes} };
    say "  PROBLEM: $_" for @{ $report->{problems} };
    if ($report->{ok}) {
        say "Approved request #$id.";
    } else {
        say "Request #$id was processed, but check it in CiviCRM: see the problems above.";
        exit 1;
    }
}
elsif ($command eq 'reject') {
    pod2usage("reject needs a request number\n") unless defined $id;
    my $request = $queue->get($id);
    say $queue->format_request($request);
    exit 1 unless confirm("Reject request #$id?");

    $queue->reject($id);
    say "Rejected request #$id.";
}
else {
    pod2usage("Unknown command '$command'\n");
}

sub confirm {
    my ($question) = @_;
    return 1 if $yes;
    print "$question [y/N] ";
    my $answer = <STDIN> // '';
    return 1 if $answer =~ /\A\s*y(es)?\s*\z/i;
    say 'Nothing changed.';
    return 0;
}

__END__

=head1 NAME

civicrm-form-queue.pl - Approve or reject "Add someone to your membership" requests

=head1 SYNOPSIS

    civicrm-form-queue.pl list
    civicrm-form-queue.pl show 19
    civicrm-form-queue.pl approve 19
    civicrm-form-queue.pl reject 19

    Options:
        --yes, -y      don't ask for confirmation
        --form NAME    a different FormBuilder form (default
                       afformAddSomeoneToYourMembership)
        --help, -h     full help

=head1 DESCRIPTION

Membership holders ask for someone to be added to their membership with a
CiviCRM FormBuilder form. Each request waits in CiviCRM's queue until it's
approved or rejected. CiviCRM's own submissions page
(https://bacds.civicrm.org/civicrm/admin/afform/submissions?name=afformAddSomeoneToYourMembership)
does that too, once it works on our PHP version; see
https://github.com/civicrm/civicrm-core/pull/37453.

=over 4

=item list

Shows the requests waiting for review.

=item show N

Shows request N, including everything submitted on the form.

=item approve N

Saves request N to CiviCRM: creates (or matches) the new person and adds
their relationship to the holder, which normally gives them an inherited
membership. Then checks that all that actually happened, since CiviCRM
doesn't report most failures, and exits non-zero if it didn't.

=item reject N

Marks request N as rejected. Nothing from it is saved.

=back

Uses the CiviCRM API key in ~/.civicrm-api-key or
/var/www/bacds.org/dance-scheduler/private/civicrm-api-key; see
bacds::Scheduler::CiviCRM.

=cut
