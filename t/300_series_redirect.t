use 5.32.1;
use warnings;
use utf8;

use Data::Dump qw/dump/;
use DateTime::Format::Strptime qw/strptime/;
use DateTime;
use JSON::MaybeXS qw/decode_json/;
use Plack::Test;
use Ref::Util qw/is_coderef/;
use Test::Differences qw/eq_or_diff/;
use Test::More;
use HTTP::Request::Common;

use bacds::Scheduler::Util::Test qw/setup_test_db get_tester/;
use bacds::Scheduler::Util::Time qw/get_now/;
use bacds::Scheduler::Util::Db qw/get_dbh/;

setup_test_db;
my $test = get_tester(auth => 1);

my $dbh = get_dbh();

plan tests => 2;

subtest 'No match' => \&test_no_match;
subtest 'Test match' => \&test_match;

sub test_no_match {
  plan tests => 2;
  $test->get('/series/foo/bar');
  is $test->response->code, 404, 'No match returns 404' or dump $test->response;
  like $test->response->decoded_content, qr{Can&#39;t find a series for &quot;/series/foo/bar&quot;}, 'No match returns desired error';
};

sub test_match {
  plan tests => 2;

  $ENV{TEST_NOW} = 1651112285;
  my $new_series = {
    name       => 'This is the correct series',
    series_xid => 'THE-RIGHT-ONE',
    frequency  => 'second and fourth Trewday',
    series_id   => '', # the webapp sends
                        # name=New+Series&frequency=monthly&is_deleted=0&series_id=
    display_text => 'this is display text',
    short_desc   => 'this is short desc',
    sidebar      => 'this is sidebar',
    series_url   => '/series/foo/bar',
    photo_url    => 'https://photo.jpg',
    manager      => 'Mary Manager',
    programmer_notes => 'this is programmer notes',
  };
  $test->request(POST '/series/', $new_series);
  $new_series = {
    name       => 'Bree Trewsday English',
    series_xid => 'THE-WRONG-ONE',
    frequency  => 'second and fourth Trewday',
    series_id   => '', # the webapp sends
                        # name=New+Series&frequency=monthly&is_deleted=0&series_id=
    display_text => 'this is display text',
    short_desc   => 'this is short desc',
    sidebar      => 'this is sidebar',
    series_url   => '/series/foo/bars',
    photo_url    => 'https://photo.jpg',
    manager      => 'Mary Manager',
    programmer_notes => 'this is programmer notes',
  };
  $test->post('/series/', $new_series);

  $test->get_ok('/series/foo/bar', 'Match returns success') or dump $test->response;

  like $test->response->decoded_content, qr{This is the correct series</a>}, 'Matches correct series' or dump $test->response;

};

