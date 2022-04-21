use 5.16.0;
use warnings;
use JSON qw/decode_json/;
use Data::Dump qw/dump/;

use bacds::Scheduler;
use bacds::Scheduler::Schema;
use Test::More tests => 25;
use Plack::Test;
use HTTP::Request::Common;
use Ref::Util qw/is_coderef/;
use URL::Encode qw/url_encode/;

unlink "testdb";

$ENV{TEST_DSN} = 'dbi:SQLite:dbname=testdb';
# load an in-memory database and deploy the required tables
bacds::Scheduler::Schema->connection($ENV{TEST_DSN},'','');
bacds::Scheduler::Schema->load_namespaces;
bacds::Scheduler::Schema->deploy;

my $app = bacds::Scheduler->to_app;

my $test = Plack::Test->create($app);
my $res;
my $decoded; 
my $expected;
my $data;


$res = $test->request( GET '/style/1' );
ok($res->is_success, '[GET /style/1] for no id match');
$decoded = decode_json($res->content);
$expected = {
    error => 'Nothing Found for style_id 1',
    errornum => 100,
};
is_deeply $decoded, $expected, '[GET /style/1] error msg' or diag explain $decoded;

$data = {
  name    => "Test style",
  };
$res = $test->request(POST '/style/', $data );
ok($res->is_success, '[POST /style/]');
$decoded = decode_json($res->content);
is $decoded->{data}{name}, $data->{name}, '[POST /style/] name' or diag explain $decoded;

$res  = $test->request( GET '/style/1' );
ok( $res->is_success, '[GET /style/1]' );
$decoded = decode_json($res->content); 
foreach my $key (sort keys %$data){
    is $decoded->{data}{$key}, $data->{$key}, "Checking $key" or diag explain $decoded;
};

$data = {
    end_time    => "2022-05-01T22:00:00",
    style_id    => 1,
    is_camp     => 1,
    long_desc   => "this is the long desc",
    name        => "saturday night test style",
    series_id   => undef,
    short_desc  => "itsa shortdesc",
    start_time  => "2022-05-01T20:00:00",
};
$res = $test->request( PUT '/style/1' , content => $data);
ok( $res->is_success, '[PUT /style/1] ' );
my $dbh = bacds::Scheduler->get_dbh();
my $resultset = $dbh->resultset('Event')->search(
    { style_id=> { '=' => 1 } } # SQL::Abstract::Classic
);
$resultset or die "empty set"; #TODO: More gracefully
my $style = $resultset->next; #it's searching on primary key, there will only be 0 or 1 result
is $style->is_camp, 1, '[PUT /style/1] changes is_camp ';


$data = {
    end_time    => "2022-05-01T22:00:00",
    style_id    => 1,
    is_camp     => 1,
    long_desc   => "this is the long desc",
    name        => "saturday night test style",
    series_id   => undef,
    short_desc  => "itsa shortdesc",
    start_time  => "2022-05-01T20:00:00",
};
$res  = $test->request( GET '/styles' );
ok( $res->is_success, '[GET /styles] ' );
$decoded = decode_json($res->content);
foreach my $style (@{$decoded->{data}}){
    foreach my $key (sort keys %$data){
        is $style->{$key}, $data->{$key}, "Checking $key" or diag explain $style;
    }
}
