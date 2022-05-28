package bacds::Scheduler::Util::TestDb;

use 5.16.0;
use warnings;

use File::Basename qw/basename/;
use FindBin qw/$Bin/;

use Exporter 'import';
our @EXPORT_OK = qw/setup_test_db/;


sub setup_test_db{

    my $test_script = basename $0, '.t';

    mkdir "$Bin/testdbs"; # might already exist, that's ok

    my $test_db = "$Bin/testdbs/testdb.$test_script.sqlite";

    unlink $test_db;

    $ENV{TEST_DSN} = "dbi:SQLite:dbname=$test_db";
    # load an on-disk test database and deploy the required tables
    bacds::Scheduler::Schema->connection($ENV{TEST_DSN},'','');
    bacds::Scheduler::Schema->load_namespaces;
    bacds::Scheduler::Schema->deploy;
}

1;
