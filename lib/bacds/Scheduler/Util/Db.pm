=head1 NAME

bacds::Scheduler::Util::Db - database utilities

=head1 SYNOPSIS

    use bacds::Scheduler::Util::Db qw/get_dbh/;

=cut

package bacds::Scheduler::Util::Db;

use 5.16.0;
use warnings;

use Data::Dump qw/dump/;

use Exporter 'import';
our @EXPORT_OK = qw/get_dbh/;

use bacds::Scheduler::Schema;


=head2 get_dbh(debug => 1)

Knows to use $ENV{TEST_DSN} from the unit tests if set.

If using the production mysql dsn will read the mysql password from the first
readable one of:

    /var/www/bacds.org/dance-scheduler/private/mysql-password
    ~/.mysql-password

Can also set $ENV{DBIX_DEBUG} instead of passing debug => 1.

=cut

sub get_dbh {
    my (%args) = @_;

    my $database = 'schedule';
    my $hostname = 'localhost';
    my $port = 3306;

    my $dbi_dsn = $ENV{TEST_DSN} ||
                  "DBI:mysql:database=$database;host=$hostname;port=$port";

    my %dbi_params = (
        mysql_enable_utf8 => 1,
        AutoCommit => 1, # recommended by DBIx::Class::Schema
    );

    if ($dbi_dsn =~ /^dbi::SQLite/) { # unit tests
        require DBD::SQLite::Constants;
        $dbi_params{sqlite_string_mode} =
            DBD::SQLite::Constants::DBD_SQLITE_STRING_MODE_UNICODE_FALLBACK();
        $dbi_params{sqlite_unicode} = 1,
    }

    my $password = _get_password();
    my $user = 'scheduler';

    my $dbh = bacds::Scheduler::Schema->connect($dbi_dsn, $user, $password, \%dbi_params);

    if ($ENV{DBIX_DEBUG} || $args{debug}) {
      $dbh->storage->debug(1);
    }

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
    my $user_pw_file = $ENV{HOME} ? "$ENV{HOME}/.mysql-password" : undef;

    if (-r $system_pw_file) {
        open my $fh, "<", $system_pw_file
            or die "can't read $system_pw_file: $!";
        $_password = <$fh>;
        chomp $_password;
    } elsif ($user_pw_file and -e $user_pw_file) {
        open my $fh, "<", $user_pw_file
            or die "can't read $user_pw_file: $!";
        $_password = <$fh>;
        chomp $_password;
    } else {
        die "please populate $system_pw_file if this is apache/mod_perl or ~/.mysql-password for running as yourself.";
    }

    return $_password;
}

1;
