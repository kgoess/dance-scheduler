package bacds::Scheduler::Util::Db;

use 5.16.0;
use warnings;

use Dancer2;
use Data::Dump qw/dump/;
use DateTime;

use Exporter 'import';
our @EXPORT_OK = qw/get_dbh/;

use bacds::Scheduler::Schema;


sub get_dbh {
    my $database = 'schedule';
    my $hostname = 'localhost';
    my $port = 3306;
    my $password = `cat ~/.mysql-password`;
    chomp $password;
    my $user = 'scheduler';
    my %dbi_params = ();

    my $dbi_dsn = $ENV{TEST_DSN} || "DBI:mysql:database=$database;host=$hostname;port=$port";

    my $dbh = bacds::Scheduler::Schema->connect($dbi_dsn, $user, $password, \%dbi_params)
        or die "can't connect"; #TODO: More gracefully

    return $dbh;
}

true;
