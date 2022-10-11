#!/usr/bin/env perl

use 5.16.0;
use warnings;

use Getopt::Long;
use Pod::Usage qw/pod2usage/;

use bacds::Scheduler::Util::Db qw/get_dbh/;

my ($name, $email, $is_superuser, $help);
GetOptions(
    'n|name=s' => \$name,
    'e|email=s' => \$email,
    'is-superuser' => \$is_superuser,
    'h|help' => \$help,
) or die("Error in command line arguments\n");

if ($help || !($name && $email)) {
    pod2usage(-verbose => 2);
}

my $dbh = get_dbh();
my $new = $dbh->resultset('Programmer')->new({
    name => $name,
    is_superuser => $is_superuser,
    email => $email,
    is_deleted => 0,
});

$new->insert;

say "New user $email/$name is in the database";

exit;


__END__
=head1 NAME

dance-scheduler-add-programmer.pl - add a login for a programmer

=head1 SYNOPSIS

    $ dance-scheduler-add-programmer.pl --name 'Alice Programmer' --email alice@example.com

Also accepts --is-superuser.

=head1 DESCRIPTION

Read access to the main javascript app at https://bacds.org/dance-scheduler/
requires an entry in the programmer's table. They can log in via the Facebook
or Google buttons on the /signin.html page, or they can use the
/bacds-signin.html page to enter a password, but in the end the results of
all of those are checked against the values in the database in
"programmers.email".

Generally you should use the web UI to add programmers, but you can use
this script to bootstrap an empty freshly-migrated system.

