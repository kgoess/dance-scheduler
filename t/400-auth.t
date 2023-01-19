
# testing bacds::Scheduler::FederatedAuth in isolation

use 5.16.0;
use warnings;
use utf8;

use Data::Dump qw/dump/;
use Encode qw/decode_utf8/;
use FindBin qw/$Bin/;
use HTTP::Request::Common;
use JSON::MaybeXS qw/decode_json/;
use Plack::Test;
use Test::More tests => 62;
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
    like $res->content, qr{<h1>Error 400 - Bad Request :\(</h1>}, 'bad request';

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
    warning_is {
        $res = $test->request(POST '/bacds-signin', $bad_params);
    } qq{login failure for nobody\@evil.ru: No programmer found for 'nobody\@evil.ru'\n};
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
    warning_is {
        $res = $test->request(POST '/bacds-signin', $wrong_pw_params);
    } qq{login failure for bacds\@loginner.com: Incorrect password\n};
    is $res->code, 401, 'wrong pw gets a 401';
    like $res->content, qr{Unauthorized!}, 'bad request gets "Unauthorized"';

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
    my $test_authed = get_tester(
        auth => 1,
    );
    my $test_series_programmer = get_tester(
        auth => 1,
        user_email => 'caneditseries@example.com',
    );
    my $test_event_programmer = get_tester(
        auth => 1,
        user_email => 'caneditevent@example.com',
    );
    my $test_programmer = get_tester(
        auth => 1,
        user_email => 'cannotedit@example.com',
    );
    my $test_other_event_programmer = get_tester(
        auth => 1,
        user_email => 'caneditjustnotthisone@example.com',
    );
    my $dbh = get_dbh();

    my $series_programmer = $dbh->resultset('Programmer')->new({
        name => 'Series Programmer',
        is_superuser => 0,
        email => 'caneditseries@example.com',
        is_deleted => 0,
    });
    $series_programmer->insert;
    my $series = $dbh->resultset('Series')->new({
        name => 'a series',
        series_xid => 'ASERIES',
        is_deleted => 0,
    });
    $series->insert;
    $series_programmer->add_to_series($series, {ordering => 1});

    my $event_programmer = $dbh->resultset('Programmer')->new({
        name => 'Event Programmer',
        is_superuser => 0,
        email => 'caneditevent@example.com',
        is_deleted => 0,
    });
    $event_programmer->insert;

    my $programmer = $dbh->resultset('Programmer')->new({
        name => 'Unevented Programmer',
        is_superuser => 0,
        email => 'cannotedit@example.com',
        is_deleted => 0,
    });
    $programmer->insert;

    my $other_event_programmer = $dbh->resultset('Programmer')->new({
        name => 'Otherevent Programmer',
        is_superuser => 0,
        email => 'caneditjustnotthisone@example.com',
        is_deleted => 0,
    });
    $other_event_programmer->insert;

    my $new_event = {
        series_id      => $series->series_id,
        start_date     => "2022-05-01",
        start_time     => "20:00",
        end_date       => "2022-05-01",
        end_time       => "22:00",
        short_desc     => "itsa shortdesc",
        custom_url     => 'https://event.url',
        custom_pricing => '¥4,000',
        name           => "saturday night test event £ ウ",
        is_canceled    => 0,
        is_series_defaults    => 0,
        synthetic_name => 'Saturday Night Test',
    };
    my ($content, $res, $res_data);

    #
    # any logged-in user can create an event
    #
    $test_authed->post_ok('/event/', $new_event, 'authed can create event');
    $content = $test_authed->res->content;
    $res_data = decode_json $content;
    ok $res_data->{data}{event_id},
        "POST created event # $res_data->{data}{event_id}";
    my $new_event_id = $res_data->{data}{event_id};
    is $res_data->{data}{name}, "saturday night test event £ ウ",
        '...with good json';
    is_deeply $res_data->{errors}, [],
        '...and with no errors';

    # link the $event_programmer to that event
    $event_programmer->add_to_events({event_id => $new_event_id});

    my $event_edit = {
        start_date     => "2022-05-01",
        start_time     => "20:00",
        end_date       => "2022-05-01",
        end_time       => "22:00",
        short_desc     => "change 無為",
        custom_url     => 'https://event.url',
        custom_pricing => '¥4,000',
        name           => "saturday night test event £ ウ",
        is_canceled    => 0,
        synthetic_name => 'Saturday Night Test',
    };

    #
    # the series programmer can edit the event
    #
    $test_series_programmer->put_ok("/event/$new_event_id", {content => $event_edit},
         'series programmer can edit the event');
    $content = $test_series_programmer->res->content;
    $res_data = decode_json $content;
    is $res_data->{data}{short_desc}, "change 無為",
        'the desc was changed to a UTF8 char';

    #
    # the event programmer can edit the event
    #
    $test_event_programmer->put_ok("/event/$new_event_id", {content => $event_edit},
         'the event programmer can edit the event');

    #
    # some unaffiliated programmer can NOT edit the event
    #
    $test_programmer->put("/event/$new_event_id", content => $event_edit);
    is $test_programmer->res->code, '403',
        'unaffiliated programmer gets a 403';

    #
    # not-logged-in user gets a redirect
    #
    $test_noauth->post('/event/', $new_event);
    is $test_noauth->res->code, '303',
        "not-logged-in user can't do jack";
    $content = $test_noauth->res->content;
    like $content, qr{This item has moved <a href="http://localhost/signin.html">here</a>},
        'html redirect getting appropriate message'; 

    #
    # JSON not-logged-in user gets a 401 error
    #
    $test_noauth->post('/event/', $new_event, accept => 'application/json');
    is $test_noauth->res->code, '401',
        "not-logged-in json can't do jack either";
    $content = decode_json($test_noauth->res->content);
    is $content->{errors}[0]{msg}, "You are not logged in",
        'JSON not logged in getting appropriate error' or diag explain $content;

    #
    # some other user has permissions but not to this particular event
    #
    my $other_event = {
        series_id      => $series->series_id,
        start_date     => "2022-05-01",
        start_time     => "20:00",
        end_date       => "2022-05-01",
        end_time       => "22:00",
        short_desc     => "some other event",
        custom_url     => 'https://other.url',
        custom_pricing => '99',
        name           => "some other event",
        is_canceled    => 0,
        is_series_defaults    => 0,
        synthetic_name => 'some other event',
    };
    # verify that this programmer doesn't have permissions to create
    # an event under this series
    $res = $test_other_event_programmer->post('/event/', $other_event);
    is $res->code, '403', 'no permission to create event in series 1';
    like $res->content, qr{You do not have permission to create this event} or diag $res->content;

    # so use the series programmer to create this other event
    $test_series_programmer->post_ok('/event/', $other_event,
        'created other event');
    $res = $test_series_programmer->res;
    is $res->code, '200', 'create other_event got 200 ok'
        or BAIL_OUT($res->content);;
    $content = $res->content;
    $res_data = decode_json $content;
    ok $res_data->{data}{event_id},
         "POST created other event # $res_data->{data}{event_id}";
    is_deeply $res_data->{errors}, [],
        '...and with no errors';
    my $other_event_id = $res_data->{data}{event_id};

    # link the $other_event_programmer to that event
    $other_event_programmer->add_to_events({event_id => $other_event_id});

    # which they can edit
    my $other_event_edit = {
        %$other_event,
        name => "changed name for other event",
    };
    $test_other_event_programmer->put_ok("/event/$other_event_id", {content => $other_event_edit},
        "sure, the other event programmer can edit *their* event");

    # but the other_event_programmer can't edit the *first* event
    $res = $test_other_event_programmer->put("/event/$new_event_id", content => $event_edit);
    is $res->code, 403, 'other event programmer gets a 403';
    $res_data = decode_json $res->content;
    is $res_data->{errors}[0]{msg}, "You do not have permission to modify this event",
        "and got expected error message";

}

