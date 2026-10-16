# Tests for the error hooks in bacds::Scheduler that send errors as JSON to
# clients that ask for it, like the scheduler's javascript

use 5.32.1;
use warnings;

use Data::Dump qw/dump/;
use HTTP::Request::Common;
use JSON::MaybeXS qw/decode_json/;
use Test::More tests => 30;

use bacds::Scheduler;
use bacds::Scheduler::Util::Db qw/get_dbh/;
use bacds::Scheduler::Util::Test qw/setup_test_db get_tester/;

setup_test_db;

# what jQuery sends for dataType: 'json'
my $Json_Accept = 'application/json, text/javascript, */*; q=0.01';
# what a browser sends for a page
my $Html_Accept = 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8';

# a route that blows up, like a model hitting a database error
{
    package bacds::Scheduler;
    get '/test-route-that-dies' => sub { die "kaboom in the model\n" };
}

# keep Dancer2's "Route exception" log lines out of the test output
bacds::Scheduler->dsl->set(logger => 'capture');

my $test = get_tester();
my ($res, $data);

sub json_errors {
    my ($res) = @_;
    my $data = eval { decode_json($res->content) }
        or return fail('response is JSON') && diag $res->content;
    return $data->{errors};
}

#
# an exception
#
bacds::Scheduler::set(show_errors => 0);
$res = $test->request(GET '/test-route-that-dies', Accept => $Json_Accept);
is $res->code, 500, 'exception for a JSON client is still a 500';
like $res->header('Content-Type'), qr{^application/json}, 'but sent as JSON';
my $errors = json_errors($res);
is scalar(@$errors), 1, 'with one error';
is $errors->[0]{num}, 500, 'numbered 500';
like $errors->[0]{msg}, qr{Something went wrong on the server}, 'with a generic message';
unlike $errors->[0]{msg}, qr{kaboom}, "that doesn't show the exception";

bacds::Scheduler::set(show_errors => 1);
$res = $test->request(GET '/test-route-that-dies', Accept => $Json_Accept);
$errors = json_errors($res);
like $errors->[0]{msg}, qr{Something went wrong.*kaboom in the model}s,
    'with show_errors on, the exception is included';
bacds::Scheduler::set(show_errors => 0);

$res = $test->request(GET '/test-route-that-dies', Accept => $Html_Accept);
is $res->code, 500, 'exception for a browser is a 500';
like $res->header('Content-Type'), qr{^text/html}, 'as HTML';
like $res->content, qr{<h1>Error 500}, 'the usual error page';

$res = $test->request(GET '/test-route-that-dies');
like $res->header('Content-Type'), qr{^text/html}, 'no Accept header gets HTML';

$res = $test->request(GET '/test-route-that-dies', Accept => '*/*');
like $res->header('Content-Type'), qr{^text/html}, 'Accept */* (curl) gets HTML';

#
# send_error
#
$res = $test->request(POST '/google-signin', Accept => $Json_Accept);
is $res->code, 400, 'send_error for a JSON client keeps its status';
$errors = json_errors($res);
is $errors->[0]{num}, 400, 'numbered with the status';
is $errors->[0]{msg}, 'missing parameter "credential"', 'with the send_error message';

$res = $test->request(POST '/google-signin', Accept => $Html_Accept);
like $res->content, qr{<title>Error 400 - Bad Request</title>}, 'browsers still get the HTML page';

#
# not found
#
$res = $test->request(GET '/no-such-route', Accept => $Json_Accept);
is $res->code, 404, 'unknown route for a JSON client is a 404';
$errors = json_errors($res);
is $errors->[0]{num}, 404, 'numbered 404';
like $errors->[0]{msg}, qr{/no-such-route}, 'naming the path';

#
# can_edit_event used to die for a missing or unknown event
#
get_dbh()->resultset('Programmer')->create({
    name         => 'Paul Programmer',
    email        => 'paul@programmer.com',
    is_superuser => 0,
    is_deleted   => 0,
});
my $programmer = get_tester(auth => 1, user_email => 'paul@programmer.com');

$res = $programmer->request(PUT '/event/999999', Accept => $Json_Accept,
    Content => [ name => 'x' ]);
is $res->code, 404, 'editing an unknown event is a 404, not a 500';
like $res->header('Content-Type'), qr{^application/json}, 'as JSON';
$errors = json_errors($res);
is $errors->[0]{num}, 40401, 'error 40401';
is $errors->[0]{msg}, "There's no event 999999", 'naming the event';

$res = $programmer->request(PUT '/event/0', Accept => $Json_Accept,
    Content => [ name => 'x' ]);
is $res->code, 400, 'editing event 0 is a 400';
$errors = json_errors($res);
is $errors->[0]{num}, 40001, 'error 40001';

# the 403s still work after moving them into json_error
$res = $programmer->request(POST '/style/', Accept => $Json_Accept,
    Content => [ name => 'NEWSTYLE' ]);
is $res->code, 403, 'non-superuser creating a style is a 403';
$errors = json_errors($res);
is $errors->[0]{num}, 40302, 'error 40302';
is $errors->[0]{msg}, 'You do not have permission to do that', 'with the usual message';

my $logged = bacds::Scheduler->dsl->dancer_app->logger_engine->trapper->read;
ok( (grep { $_->{message} =~ /kaboom in the model/ } @$logged),
    'the exception was still logged');
ok( !(grep { $_->{message} =~ /There's no event/ } @$logged),
    "the 404 for an unknown event isn't logged as an exception");

bacds::Scheduler->dsl->set(logger => 'console');
