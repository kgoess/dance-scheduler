use 5.16.0;
use warnings;

use JSON::MaybeXS qw/decode_json/;
use Data::Dump qw/dump/;
use Test::More tests => 4;
use Plack::Test;
use HTTP::Request::Common;
use Ref::Util qw/is_coderef/;

use bacds::Scheduler;
use bacds::Scheduler::Schema;
use bacds::Scheduler::Util::TestDb qw/setup_test_db GET/;

setup_test_db();


my $app = bacds::Scheduler->to_app;
ok( is_coderef($app), 'Got app' );

my $test = Plack::Test->create($app);
my $res;
my $decoded; 
my $expected;
my $data;

$res = $test->request( HTTP::Request::Common::GET '/');
is $res->code, '303',
    'unauthenticated request to / returns 303';
is $res->header('location'), '/signin.html',
    'unauthenticated request to / returns redirect to signin.html';

$res  = $test->request( GET '/' );
ok( $res->is_success, '[GET /]' )
    or die join ': ', $res->code, $res->content;
