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


=head2 get_dbh(debug => 1), get_dbh(db => 'schedule[_test]')

Knows to use $ENV{TEST_DSN} from the unit tests if set (which points to SQLite,
see t/testdbs/, which you can access via e.g.

    sqlite3 -header -column \
        t/testdbs/testdb.100_styles.sqlite  \
        'select * from styles'

otherwise determines db and user as one of "scheduler" or "scheduler_test" from
%args,

otherwise checks DANCER_ENVIRONMENT eq 'production'.

If using the production table "schedule", then mysql dsn will read the mysql
password from:

    /var/www/bacds.org/dance-scheduler/private/mysql-password

otherwise we're using the "schedule_test" table, probably via
"plackup -Ilib -p 5000 bin/app.psgi" so we'll get the password from:

    ~/.mysql-password

You can also set $ENV{DBIX_DEBUG} instead of passing debug => 1.

=cut

sub get_dbh {
    my (%args) = @_;

    # $ENV{TEST_DSN} ignores $database entirely anyway ::shrug::
    state $database = _get_name_for('db', %args);
    state $user     = _get_name_for('user', %args);

    my $hostname = 'localhost';
    #my $port = 3306;
    # MariaDB says: "port cannot be specified when host is localhost" ok, whatever

    my $dbi_dsn = $ENV{TEST_DSN} ||
                  #"DBI:MariaDB:database=$database;host=$hostname;port=$port";
                  "DBI:MariaDB:database=$database;host=$hostname";

    my %dbi_params = (
        # mysql_enable_utf8 => 1, not needed for mariadb
        AutoCommit => 1, # recommended by DBIx::Class::Schema
    );

    if ($dbi_dsn =~ /^dbi:SQLite/) { # unit tests

        require DBD::SQLite::Constants;
        $dbi_params{sqlite_string_mode} =
            DBD::SQLite::Constants::DBD_SQLITE_STRING_MODE_UNICODE_FALLBACK();

        $dbi_params{sqlite_unicode} = 1;
    }

    my $password = _get_password_for($database);

    my $dbh = bacds::Scheduler::Schema->connect($dbi_dsn, $user, $password, \%dbi_params);

    if ($ENV{DBIX_DEBUG} || $args{debug}) {
      warn "connecting to $dbi_dsn as '$user'\n";
      $dbh->storage->debug(1);
    }

    return $dbh;
}

=head2 using_test_db

Returns a boolean for whether we're in test mode, for the schedule
accordion to show "Using the production_test db".

=cut

sub using_test_db {
    my ($database) = _get_name_for('db');
    return $database =~ /_test$/ ? $database : undef;
}

# get "db" or "user" from wherever
sub _get_name_for {
    my ($what, %args) = @_;

    my $default = $what eq 'db' ? 'schedule' : 'scheduler';

    my $name;

    if ($ENV{TEST_DSN}) {
        $name = 'ignored in favor of TEST_DSN';

    } elsif ($args{$what}) {
        # passed in from CLI scripts
        $name = $args{$what};

    } elsif (($ENV{DANCER_ENVIRONMENT}//'') eq 'production') {
        # DANCER_ENVIRONMENT is set in httpd.conf.d/dance-scheduler.conf
        $name = $default;

    } else {
        # "plackup -p 5000" running in git checkout directory
        $name = $default.'_test';
    }

    return $name;
}


my $_password;
sub _get_password_for {
    my ($database) = @_;
    $database or die "missing database arg in call to _get_password_for";

    return $_password if $_password;

    if ($database eq 'schedule') {
        my $system_pw_file = '/var/www/bacds.org/dance-scheduler/private/mysql-password';
        open my $fh, "<", $system_pw_file
            or die "can't read $system_pw_file: $!";
        $_password = <$fh>;
        chomp $_password;

    } elsif ($database eq 'schedule_test') {
        $ENV{HOME} or die "can't find password for db 'schedule_test' without ENV{HOME} set";
        my $user_pw_file = "$ENV{HOME}/.mysql-password";
        open my $fh, "<", $user_pw_file
            or die "can't read $user_pw_file for db 'schedule_test': $!";
        $_password = <$fh>;
        chomp $_password;

    } elsif ($database =~ /^ignored/) {
        $_password = 'ignored in favor of TEST_DSN';

    } else {
        die "_get_password_for doesn't understand arg '$database'";
    }

    return $_password;
}

1;
