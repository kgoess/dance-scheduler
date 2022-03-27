use 5.16.0;
use warnings;
use JSON qw/decode_json/;
use Data::Dump qw/dump/;

use bacds::Scheduler;
use Test::More tests => 4;
use Plack::Test;
use HTTP::Request::Common;
use Ref::Util qw<is_coderef>;

my $app = bacds::Scheduler->to_app;
ok( is_coderef($app), 'Got app' );

my $test = Plack::Test->create($app);
my $res  = $test->request( GET '/' );

ok( $res->is_success, '[GET /] successful' );

$res  = $test->request( GET '/event/1' );

ok( $res->is_success, '[GET /event/1] successful' );
my $decoded = decode_json($res->content);
my $expected = {
  created_ts  => "2022-03-26T19:30:17",
  end_time    => "2022-05-01T22:00:00",
  event_id    => 1,
  event_type  => "ONEDAY",
  is_camp     => 0,
  is_template => 0,
  long_desc   => "this is the long desc",
  modified_ts => "2022-03-26T19:30:17",
  name        => "saturday night test event",
  series_id   => undef,
  short_desc  => "itsa shortdesc",
  start_time  => "2022-05-01T20:00:00",
}; #change to use fixture
is_deeply $decoded, $expected, '[GET/event/1] match' or dump $decoded;
