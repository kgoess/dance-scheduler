
# testing bacds::Scheduler::Auth in isolation

use 5.16.0;
use warnings;

use Data::Dump qw/dump/;
use FindBin qw/$Bin/;
use HTTP::Request::Common;
use Plack::Test;
use Test::More tests => 11;

use bacds::Scheduler;
use bacds::Scheduler::Auth;

$ENV{TEST_CACHE_PATH} = "$Bin/cache"; # s/b t/cache/

test_fetch_google_oauth_keys();
test_google_login();


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

    $res = $test->request(POST '/google-signin', {credential => 'notarealcredential'});
    is $res->code, 400, 'got 400';
    like $res->content, qr{<h1>Error 400 - Bad Request</h1>}, 'bad request';
    like $res->content, qr{JWT: invalid token format}, 'invalid token';

    my $jwt = "eyJhbGciOiJIUzI1NiJ9.dGVzdA.ujBihtLSr66CEWqN74SpLUkv28lra_CeHnxLmLNp4Jo";
    $res = $test->request(POST '/google-signin', {credential => $jwt});
    is $res->code, 400, 'got 400';
    like $res->content, qr{<h1>Error 400 - Bad Request</h1>}, 'bad request';
    like $res->content, qr{JWS: kid_keys lookup failed}, 'invalid jwt';



}

