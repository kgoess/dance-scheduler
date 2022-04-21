use 5.16.0;
use warnings;
use JSON qw/decode_json/;
use Data::Dump qw/dump/;

use bacds::Scheduler;
use bacds::Scheduler::Schema;
use Test::More tests => 2;
use Plack::Test;
use HTTP::Request::Common;
use Ref::Util qw/is_coderef/;
use URL::Encode qw/url_encode/;

my $app = bacds::Scheduler->to_app;
ok( is_coderef($app), 'Got app' );

my $test = Plack::Test->create($app);
my $res;
my $decoded; 
my $expected;
my $data;

$res  = $test->request( GET '/' );
ok( $res->is_success, '[GET /]' );
