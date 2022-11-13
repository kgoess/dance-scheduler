#!/usr/bin/env perl

use 5.16.0;
use warnings;

use Getopt::Long;
use Pod::Usage qw/pod2usage/;

eval {
    require bacds::Scheduler::Util::Db;
    require bacds::Scheduler::FederatedAuth;
};
if ($@) {
   die "\nERROR: Loading the code failed, try running this first:\n\n".
    "       eval \$(perl -Mlocal::lib=/var/lib/dance-scheduler)\n\n".
    "Error was:\n$@\\nn";
}
bacds::Scheduler::Util::Db->import( qw/get_dbh/ );


my ($email, $unset, $help);
GetOptions(
    'email=s' => \$email,
    'unset' => \$unset,
    'h|help' => \$help,
) or die("Error in command line arguments\n");

if ($help || !$email) {
    pod2usage(-verbose => 2);
}

my $dbh = get_dbh();
my $rs = $dbh->resultset('Programmer')->search({
    email => $email
});

my $programmer = $rs->first or die "no programmer '$email' in the database'\n";

if ($unset) {
    $programmer->password_hash('');
    $programmer->update;
    say "Password unset for '$email'";
    exit;
}

print "> enter password: ";
my $password = <STDIN>;
chomp $password;

$password or die "You didn't enter anything?\n";

my $entry = bacds::Scheduler::FederatedAuth->make_password_entry($password);
$programmer->password_hash($entry);
$programmer->update;
say "Password set for '$email'";
exit;



__END__
=head1 NAME

dance-scheduler-user-password.pl - set the password for a user

=head1 SYNOPSIS

    $ dance-scheduler-user-password.pl --email foo@bar.com
    > enter password: paSSw0rd

Or to unset a password (and force them to log in via facebook/google)

    $ dance-scheduler-user-password.pl --email foo@bar.com --unset

=head1 DESCRIPTION

We want to promote people to log in to the dance scheduler webapp using
facebook or google, so that we don't have to deal with forgotten/lost passwords
and all that. But in the case where somebody has ssh access to the webserver,
they can run this utility to make a password for a given user that will work
with the /bacds-signin.html password form.

Running the script will prompt you for the password, rather than letting you
specify it on the command-line, which would be insecure in a whole bunch of
ways.

It updates programmers.password_hash in the database.

