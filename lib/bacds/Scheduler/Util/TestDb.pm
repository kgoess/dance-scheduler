package bacds::Scheduler::Util::TestDb;

use 5.16.0;
use warnings;

use File::Basename qw/basename/;
use FindBin qw/$Bin/;

use bacds::Scheduler::Util::Db qw/get_dbh/;
use bacds::Scheduler::Util::Cookie qw/LoginMethod LoginSession/;
use bacds::Scheduler::FederatedAuth;

use Exporter 'import';
our @EXPORT_OK = qw/
    setup_test_db
    GET
    PUT
    POST
/;


sub setup_test_db{

    my $test_script = basename $0, '.t';

    mkdir "$Bin/testdbs"; # might already exist, that's ok

    my $test_db = "$Bin/testdbs/testdb.$test_script.sqlite";

    if (-e $test_db) {
        unlink $test_db or die "can't unlink $test_db $!";
    }

    $ENV{TEST_DSN} = "dbi:SQLite:dbname=$test_db";
    # load an on-disk test database and deploy the required tables
    bacds::Scheduler::Schema->connection($ENV{TEST_DSN},'','');
    bacds::Scheduler::Schema->load_namespaces;
    bacds::Scheduler::Schema->deploy;

    my $dbh = get_dbh();
    my $new = $dbh->resultset('Programmer')->new({
        name => 'Peter Admin',
        is_superuser => 1,
        email => 'petertheadmin@test.com',
        is_deleted => 0,
    });

    $new->insert;
}

sub auth_cookie {
    state $session_cookie = bacds::Scheduler::FederatedAuth
        ->create_session_cookie('petertheadmin@test.com');

    return Cookie => LoginMethod()."=session;".LoginSession()."=$session_cookie"
}

sub POST { HTTP::Request::Common::POST(@_, auth_cookie()) }
sub PUT  { HTTP::Request::Common::PUT (@_, auth_cookie()) }
sub GET  { HTTP::Request::Common::GET (@_, auth_cookie()) }
# do other methods if needed: OPTIONS, DELETE, PATCH

1;
