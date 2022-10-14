
# testing bacds::Scheduler::FederatedAuth in isolation

use 5.16.0;
use warnings;

use Data::Dump qw/dump/;
use Encode qw/decode_utf8/;
use FindBin qw/$Bin/;
use HTTP::Request::Common;
use JSON::MaybeXS qw/decode_json/;
use Plack::Test;
use Test::More tests => 44;
use Test::Warn;

use bacds::Scheduler;
use bacds::Scheduler::FederatedAuth;
use bacds::Scheduler::Util::Db qw/get_dbh/;
use bacds::Scheduler::Util::Test qw/setup_test_db get_tester/;
setup_test_db;

$ENV{TEST_CACHE_PATH} = "$Bin/cache"; # s/b t/cache/

test_fetch_google_oauth_keys();
test_google_login();
test_session_key_and_cookie();
test_password_matches();
test_bacds_login();
test_requires_login();
test_can_edit();


sub test_fetch_google_oauth_keys {

    my $data = bacds::Scheduler::FederatedAuth::fetch_google_oauth_keys();

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

sub test_requires_login {
    # the / endpoint just requires you to be there with a valid login,
    # otherwise it redirects you to /signin.html

    my $test_noauth = get_tester();
    my $test_authed = get_tester(auth => 1);
    #
    # test GET /
    #
    $test_authed->get_ok('/', 'authenticated GET / succeeds');
    $test_noauth->get('/');
    ok ! $test_noauth->success, 'noauth GET / fails';
    is $test_noauth->res->code, 303, 'noauth GET / gets a 303';
    is $test_noauth->res->header('location'), 'http://localhost/signin.html', 'noauth GET / right loc';

    #
    # test GET JSON /
    #
    $test_noauth->add_header(accept=>'application/json');
    $test_noauth->get('/');
    ok ! $test_noauth->success, 'noauth GET JSON / fails';
    is $test_noauth->res->headers->content_type, 'application/json', 'noauth GET JSON returns application/json';
    is $test_noauth->res->code, 401, 'noauth GET JSON / gets a 401';
    my $json = decode_json($test_noauth->res->content);
    is_deeply $json, 
        {
          data   => { url => "http://localhost/signin.html" },
          errors => [{ msg => "You are not logged in", num => 40101 }],
        };
}

sub test_can_edit {
    # POST and PUT to /event/ require can_edit_event
    my $test_noauth = get_tester();
    my $test_authed = get_tester(auth => 1);

    my $new_event = {
        start_date     => "2022-05-01",
        start_time     => "20:00",
        end_date       => "2022-05-01",
        end_time       => "22:00",
        short_desc     => "itsa shortdesc",
        custom_url     => 'https://event.url',
        custom_pricing => '¥4,000',
        name           => "saturday night test event £ ウ",
        is_canceled    => 0,
        synthetic_name => 'Saturday Night Test',
    };
    my ($content, $res_data);
    #
    # logged-in user
    #

    $test_authed->post_ok('/event/', $new_event, 'authenticated POST / succeeds');
    $content = $test_authed->res->content;
    $res_data = decode_json $content;
    ok $res_data->{data}{event_id}, "POST created event # $res_data->{data}{event_id}";
    is $res_data->{data}{name}, decode_utf8("saturday night test event £ ウ"),
        '...with good json';
    is_deeply $res_data->{errors}, [], '...and with no errors';

    #
    # not-logged-in
    #
    # FIXME Plugin::Auth->login_redirect_json should return some JSON blob that
    # the js client understands
    $test_noauth->post('/event/', $new_event);
    is $test_noauth->res->code, '401', 'no-auth POST / fails with 401';
    $content = $test_noauth->res->content;
    
    diag "TODO test with some *other* user that doesn't have permission to ".
         "edit this *particular* event";
}

