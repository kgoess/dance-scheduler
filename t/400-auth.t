
# testing bacds::Scheduler::Auth in isolation

use 5.16.0;
use warnings;

use Data::Dump qw/dump/;
use FindBin qw/$Bin/;
use HTTP::Request::Common;
use Plack::Test;
use Test::More tests => 31;
use Test::Warn;

use bacds::Scheduler;
use bacds::Scheduler::Auth;
use bacds::Scheduler::Util::Db qw/get_dbh/;
use bacds::Scheduler::Util::Test qw/setup_test_db/;
setup_test_db;

$ENV{TEST_CACHE_PATH} = "$Bin/cache"; # s/b t/cache/

test_fetch_google_oauth_keys();
test_google_login();
test_session_key_and_cookie();
test_password_matches();
test_bacds_login();


sub test_fetch_google_oauth_keys {

    my $data = bacds::Scheduler::Auth::fetch_google_oauth_keys();

    is ref $data, 'HASH', 'looks like a hashref';

    my $keys = $data->{keys};

    is ref $keys, 'ARRAY', 'the "keys" part is an arrayref';

    is @$keys, 2, 'with two things in it';

}

# this is a light test, I'm not going to do all the setup to test success
sub test_google_login {

    my $app = bacds::Scheduler->to_app;
    my $test = Plack::Test->create($app);

    my $res;

    $res = $test->request(POST '/google-signin');
    is $res->code, 400, 'got 400';
    like $res->content, qr{<title>Error 400 - Bad Request</title>}, 'got bad request msg';
    like $res->content, qr{missing parameter &quot;credential&quot;}, 'missing param msg';

    $res = $test->request(POST '/google-signin', {credential => 'notarealcredential'});
    is $res->code, 400, 'got 400';
    like $res->content, qr{<title>Error 400 - Bad Request</title>}, 'got bad request msg';
    like $res->content, qr{JWT: invalid token format}, 'invalid token';
    my $jwt = "eyJhbGciOiJIUzI1NiJ9.dGVzdA.ujBihtLSr66CEWqN74SpLUkv28lra_CeHnxLmLNp4Jo";
    $res = $test->request(POST '/google-signin', {credential => $jwt});
    is $res->code, 400, 'got 400';
    like $res->content, qr{<h1>Error 400 - Bad Request</h1>}, 'bad request';

    like $res->content, qr{JWS: kid_keys lookup failed}, 'invalid jwt';
}

sub test_session_key_and_cookie {

    my $class = 'bacds::Scheduler::FederatedAuth';

    my $dbh = get_dbh();

    my $programmer = $dbh->resultset('Programmer')->new({
        name => 'Paul Programmer',
        is_superuser => 0,
        email => 'paul@programmer.com',
        is_deleted => 0,
    });
    $programmer->insert;

    my $admin = $dbh->resultset('Programmer')->new({
        name => 'Adele Admin',
        is_superuser => 1,
        email => 'adele@admin.com',
        is_deleted => 0,
    });
    $admin->insert;

    my $prog_session = $class->create_session_cookie('paul@programmer.com');
    my $admin_session = $class->create_session_cookie('adele@admin.com');
    my $nobody_session = $class->create_session_cookie('nobody@evil.ru');

    my ($res, $err);
    ($res, $err) =  $class->check_session_cookie($prog_session);
    ok $res, 'programmer cookie ok';
    ok !$err;

    ($res, $err) = $class->check_session_cookie($admin_session);
    ok $res, 'admin cookie ok';
    ok !$err;

    ($res, $err) = $class->check_session_cookie($nobody_session);
    ok !$res, 'nobody cookie rejected';
    like $err, qr{^no programmer found for 'nobody\@evil.ru'},
        'nobody cookie threw error';
}

sub test_password_matches {

    my $c = 'bacds::Scheduler::FederatedAuth';

    my $pw_entry = $c->make_password_entry('paSSw0rd');

    my ($alg, $salt, $hash) = split /=/, $pw_entry;
    is $alg, 'bcrypt';
    ok $salt;
    ok $hash;

    ok $c->password_matches('paSSw0rd', $pw_entry), "password_matches ok for 'paSSw0rd'";
}

sub test_bacds_login {
    my $app = bacds::Scheduler->to_app;
    my $test = Plack::Test->create($app);

    my $res;

    $res = $test->request(POST '/bacds-signin');
    is $res->code, 400, 'got 400';
    like $res->content, qr{<title>Error 400 - Bad Request</title>}, 'got bad request msg';
    like $res->content, qr{missing parameter &quot;programmer_email&quot;}, 'missing param msg';


    my $jwt = "eyJhbGciOiJIUzI1NiJ9.dGVzdA.ujBihtLSr66CEWqN74SpLUkv28lra_CeHnxLmLNp4Jo";
    my $bad_params = {
        programmer_email => 'nobody@evil.ru',
        password => 'paSSw0rd',
    };
    $res = $test->request(POST '/bacds-signin', $bad_params);
    is $res->code, 401, 'got 401';
    like $res->content, qr{Unauthorized!}, 'bad request';


    my $dbh = get_dbh();
    my $password_entry = bacds::Scheduler::FederatedAuth->make_password_entry('paSSw0rd');
    my $programmer = $dbh->resultset('Programmer')->new({
        name => 'Bacds Loginner',
        is_superuser => 0,
        email => 'bacds@loginner.com',
        password_hash => $password_entry,
        is_deleted => 0,
    });
    $programmer->insert;

    my $good_params = {
        programmer_email => 'bacds@loginner.com',
        password => 'paSSw0rd',
    };
    $res = $test->request(POST '/bacds-signin', $good_params);
    is $res->code, 303, 'successful login';
    is $res->header('location'), '/', 'success login redirect to /';

    my $wrong_pw_params = {
        programmer_email => 'bacds@loginner.com',
        password => 'not my password',
    };
    $res = $test->request(POST '/bacds-signin', $wrong_pw_params);
    is $res->code, 401, 'successful login';
    like $res->content, qr{Unauthorized!}, 'bad request';

}

