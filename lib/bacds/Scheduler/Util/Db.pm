package bacds::Scheduler::Util::Db;

use 5.16.0;
use warnings;

use Dancer2;
use Data::Dump qw/dump/;

use Exporter 'import';
our @EXPORT_OK = qw/get_dbh/;

use bacds::Scheduler::Schema;


sub get_dbh {
    my $database = 'schedule';
    my $hostname = 'localhost';
    my $port = 3306;

    my %dbi_params = ();

    my $dbi_dsn = $ENV{TEST_DSN} || "DBI:mysql:database=$database;host=$hostname;port=$port";


    my $password = _get_password();
    my $user = 'scheduler';

    my $dbh = bacds::Scheduler::Schema->connect($dbi_dsn, $user, $password, \%dbi_params)
        or die "can't connect"; #TODO: More gracefully

    return $dbh;
}


my $_password;
sub _get_password {
    return $_password if $_password;

    # see also 'perldoc Dancer2::Config' for an alternate way to store these:
    #     Next, Dancer2 will look for a file called config_local.EXT. This file is
    #     typically useful for deployment-specific configuration that should not be
    #     checked into source control. For instance, database credentials could be
    #     stored in this file.
    my $system_pw_file = '/var/www/bacds.org/dance-scheduler/private/mysql-password';
    my $user_pw_file = "$ENV{HOME}/.mysql-password";

    if (-r $system_pw_file) {
        open my $fh, "<", $system_pw_file
            or die "can't read $system_pw_file: $!";
        $_password = <$fh>;
        chomp $_password;
    } elsif (-e $user_pw_file) {
        open my $fh, "<", $user_pw_file
            or die "can't read $user_pw_file: $!";
        $_password = <$fh>;
        chomp $_password;
    } else {
        die "please populate $system_pw_file if this is apache/mod_perl or ~/.mysql-password for running as yourself.";
    }

    return $_password;
}

true;
