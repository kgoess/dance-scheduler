use 5.16.0;
use warnings;

use Data::Dump qw/dump/;
use Test::More tests => 3;
use Test::WWW::Mechanize::PSGI;

use bacds::Scheduler::Util::Test qw/setup_test_db get_tester/;

setup_test_db();


my $test_noauth = get_tester();
my $test        = get_tester(auth => 1);

$test_noauth->get('/');
is $test_noauth->res->code, '303',
    'unauthenticated request to / returns 303';
$test_noauth->header_is(location => '/signin.html',
    'unauthenticated request to / returns redirect to signin.html');

$test->get_ok('/', 'authenticated request ok')
    or die join ': ', $test->res->code, $test->res->content;

