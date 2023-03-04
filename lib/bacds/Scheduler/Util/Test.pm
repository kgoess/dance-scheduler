=head1 NAME

bacds::Scheduler::Util::Test - unit test utilities

=head1 EXPORTABLE FUNCTIONS

=cut

package bacds::Scheduler::Util::Test;

use 5.16.0;
use warnings;

use Data::Dump qw/dump/;
use File::Basename qw/basename/;
use FindBin qw/$Bin/;
use Test::WWW::Mechanize::PSGI;
use LWP::ConsoleLogger::Easy qw/debug_ua/;

use bacds::Scheduler;
use bacds::Scheduler::Util::Db qw/get_dbh/;
use bacds::Scheduler::Util::Cookie qw/LoginMethod LoginSession/;
use bacds::Scheduler::Util::Initialize;
use bacds::Scheduler::FederatedAuth;

use Exporter 'import';
our @EXPORT_OK = qw/
    setup_test_db
    get_tester
/;


=head2 setup_test_db

=cut

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

=head2 get_tester

Returns a Test::WWW::Mechanize::PSGI object (which inherits from
Test::WWW:Mechanize, WWW::Mechanize, and LWP::UserAgent) with max_redirect set
to 0.

Possible args:

 - auth => 1 set up the LoginMethod and LoginSession cookie headers
 - max_redirect => $c (default 0)
 - user_email (defaults to petertheadmin@test.com)
 - debug => [1-8] see LWP::ConsoleLogger::Easy
    (can also use $ENV{DEBUG_UA})

=cut

sub get_tester {
    my (%args) = @_;

    my $app = bacds::Scheduler->to_app;

    my $max_redirect = $args{max_redirect} || 0;

    my $test = Test::WWW::Mechanize::PSGI->new(
        app => $app,
        $args{env} ? (env => $args{env}) : (),
        max_redirect => $max_redirect,
    );
    
    my @cookies;

    if ($args{auth}) {
        push @cookies, auth_cookie($args{user_email});
    }
    if ((! exists $args{checksum}) || $args{checksum} == 1) {
        my $checksum = bacds::Scheduler::Util::Initialize::get_checksum();
        push @cookies, "Checksum=$checksum";
    }
    elsif ($args{checksum}){
        push @cookies, "Checksum=$args{checksum}";
    }

    if (@cookies) {
        my $cookie_string = join ";", @cookies;
        $test->add_header(Cookie => $cookie_string);
    }

    my $debug = $args{debug} || $ENV{DEBUG_UA};
    if (defined $debug) {
        debug_ua($test, $debug);
    }

    return $test;
}

sub auth_cookie {
    my ($email) = @_;
    $email ||= 'petertheadmin@test.com';

    my $session_cookie = bacds::Scheduler::FederatedAuth
        ->create_session_cookie($email);

    return LoginMethod()."=session;".LoginSession()."=$session_cookie"
}


1;
