use 5.16.0;
use warnings;

use Data::Dump qw/dump/;
use DateTime::Format::Strptime qw/strptime/;
use DateTime;
use HTTP::Request::Common;
use JSON::MaybeXS qw/decode_json/;
use Plack::Test;
use Ref::Util qw/is_coderef/;
use Test::Differences qw/eq_or_diff/;
use Test::More tests => 6;
use Test::Warn;

use bacds::Scheduler;
use bacds::Scheduler::Schema;
use bacds::Scheduler::Util::Time qw/get_now/;
use bacds::Scheduler::Util::Db qw/get_dbh/;

use bacds::Scheduler::Util::Test qw/setup_test_db get_tester/;
setup_test_db;

my $app = bacds::Scheduler->to_app;
my $test = get_tester(auth => 1, checksum => 0);
my $dbh = get_dbh();

my ($res, $decoded, $got, $expected);
$res = $test->request( GET '/style/1' );
ok(!$res->is_success, 'no checksum returned failure');
is ($res->code, 400, 'Missing checksum returns 400 error');

$decoded = decode_json($res->content);
$expected = {
    data => '',
    errors => [{
        msg => 
            "You have sent a JSON request without a checksum cookie. This "
            . "shouldn't be possible. Please reload the page and try again.",
        num => 400,
    }]
};
eq_or_diff $decoded, $expected, 'missing checksum error msg matches';

$test = get_tester(auth => 1, checksum => "bogus checksum");

$res = $test->request( GET '/style/1' );
ok(!$res->is_success, 'bad checksum returned failure');
is ($res->code, 426, 'Bad checksum returns 426 error');

$decoded = decode_json($res->content);
$expected = {
    data => '',
    errors => [{
        msg => "You need to reload the page to be able to complete your request",
        num => 426,
    }]
};
eq_or_diff $decoded, $expected, 'bad checksum error msg matches';
