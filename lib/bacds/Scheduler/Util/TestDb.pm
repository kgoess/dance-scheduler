package bacds::Scheduler::Util::TestDb;

use 5.16.0;
use warnings;

use Exporter 'import';
our @EXPORT_OK = qw/setup_test_db/;


sub setup_test_db{
    unlink "testdb";
    $ENV{TEST_DSN} = 'dbi:SQLite:dbname=testdb';
    # load an on-disk test database and deploy the required tables
    bacds::Scheduler::Schema->connection($ENV{TEST_DSN},'','');
    bacds::Scheduler::Schema->load_namespaces;
    bacds::Scheduler::Schema->deploy;
}

1;
