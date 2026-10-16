# testing the cross-site request check (the Origin/Referer "before" hook in
# bacds::Scheduler)

use 5.16.0;
use warnings;

use Data::Dump qw/dump/;
use HTTP::Request::Common qw/PUT/;
use JSON::MaybeXS qw/decode_json/;
use Test::More tests => 22;

use bacds::Scheduler;
use bacds::Scheduler::Util::Db qw/get_dbh/;
use bacds::Scheduler::Util::Test qw/setup_test_db get_tester/;
setup_test_db;

# the test requests go to http://localhost
my $Own_Origin = 'http://localhost';
my $Evil       = 'https://evil.example.com';

bacds::Scheduler->dsl->set(trusted_origins => ['https://www.bacds.org']);

my $test = get_tester(auth => 1);
my $dbh = get_dbh();
my $res;

# keep the expected warnings out of the test output
my @warnings;
local $SIG{__WARN__} = sub { push @warnings, @_ };

sub band_count { $dbh->resultset('Band')->count }

#
# refused
#
my $before = band_count();
$res = $test->post('/band/', { name => 'Evil Band' }, Origin => $Evil);
is $res->code, 403, 'POST from another origin is refused';
like $res->decoded_content, qr{came from another website}, 'with an explanation';
is band_count(), $before, 'and nothing was created';
like $warnings[-1], qr{refusing cross-site POST /band/ from origin "\Q$Evil\E"},
    'and it was logged';

$res = $test->post('/band/', { name => 'Evil Band' }, Origin => 'null');
is $res->code, 403, 'Origin "null" is refused';

$res = $test->post('/band/', { name => 'Evil Band' }, Referer => "$Evil/some/page.html");
is $res->code, 403, 'no Origin, Referer from another site is refused';

$res = $test->post('/band/', { name => 'Evil Band' }, Referer => 'garbage');
is $res->code, 403, 'unparseable Referer is refused';

$res = $test->post('/band/', { name => 'Evil Band' }, Origin => 'http://localhost.example.com');
is $res->code, 403, 'an origin that only starts with ours is refused';

$res = $test->request(PUT '/band/1', Origin => $Evil, Content => [ name => 'x' ]);
is $res->code, 403, 'PUT from another origin is refused';

$res = $test->post('/board-agenda/template',
    { agenda_text => 'evil', zoom_url => '' }, Origin => $Evil);
is $res->code, 403, 'routes in BoardAgenda.pm are covered too';

$res = $test->post('/unearth/member/request-link',
    { email => 'someone@example.com' }, Origin => $Evil);
is $res->code, 403, 'the member portal is covered too';

is band_count(), $before, 'none of those created anything';

#
# allowed
#
$res = $test->post('/band/', { name => 'Own Origin Band' }, Origin => $Own_Origin);
is $res->code, 200, 'POST from our own origin is allowed' or dump $res;
is band_count(), $before + 1, 'and the band was created';

$res = $test->post('/band/', { name => 'Uppercase Band' }, Origin => 'HTTP://LOCALHOST/');
is $res->code, 200, 'origin comparison ignores case and a trailing slash';

$res = $test->post('/band/', { name => 'Trusted Band' }, Origin => 'https://www.bacds.org');
is $res->code, 200, 'POST from a trusted_origins origin is allowed';

$res = $test->post('/band/', { name => 'Referer Band' }, Referer => "$Own_Origin/dance-scheduler/");
is $res->code, 200, 'no Origin, Referer from our own origin is allowed';

$res = $test->post('/band/', { name => 'No Header Band' });
is $res->code, 200, 'POST without Origin or Referer is allowed (curl, scripts)';

my $band_id = decode_json($res->decoded_content)->{data}{band_id};
$res = $test->request(PUT "/band/$band_id", Origin => $Own_Origin,
    Content => [ band_id => $band_id, name => 'Renamed Band' ]);
is $res->code, 200, 'PUT from our own origin is allowed' or dump $res;

$test->get('/bandAll', Origin => $Evil);
is $test->status, 200, 'GETs are never checked';

$res = $test->post('/google-signin', {}, Origin => 'https://accounts.google.com');
is $res->code, 400, '/google-signin is exempt (400 is for the missing credential)';

is band_count(), $before + 5, 'all the allowed POSTs created their bands';
