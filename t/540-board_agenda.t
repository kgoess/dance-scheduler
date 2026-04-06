
use 5.31.0;
use feature 'signatures';
use warnings;
no warnings 'experimental::signatures';
use utf8;

use Data::Dump qw/dump/;
use JSON::MaybeXS qw/decode_json/;
use Test::More tests => 25;
use Plack::Test;
use Test::Differences qw/eq_or_diff/;

use bacds::Scheduler::Util::Test qw/setup_test_db get_tester/;
use bacds::Scheduler::Util::Time qw/get_now/;
use bacds::Scheduler::Util::Db qw/get_dbh/;
use bacds::Scheduler::Model::BoardAgenda;

setup_test_db;

my $test = get_tester(auth => 1);
my $dbh = get_dbh();
$ENV{TEST_NOW} = 1651112285;

my ($content, $agenda, $res);

#
# set up the blank agenda template
#
my $starting_template = "Board Agenda\nDate: [MEETING DATE]\n- Item 1\n- Item 2\n[ZOOM LINK]\n";
$res = $test->post('/board-agenda/template', {
    agenda_text => $starting_template,
    zoom_url => "https://zoom.us/whatever",
});
ok $res->is_redirect, 'POST gave us a 303 redirect';
is $res->header('location'), '/board-agenda/template', 'and the redirect is to /board-agenda/template';


#
# fetch empty public agenda
#
$test->get_ok('/board-agenda');
$content = $test->content;
$content =~ m{<div id="public-meeting-agenda".*?>(.+?)</div>}ms
    or die "can't find public-meeting-agenda div in response: ".$content;
$agenda = $1;
like $agenda, qr{- Item 1\s+- Item 2}ms, 'starting with empty template in public agenda';
like $agenda, qr{\[Zoom link available to board members\]}, 'no zoom link in public agenda';
like $agenda, qr{\[MEETING DATE\]}, 'meeting date not set yet';

#
# fetch edit page
#
$test->get_ok('/board-agenda/edit');
$content = $test->content;
$content =~ m{<textarea id="agenda_text".*?>(.+)</textarea>}ms
    or die "can't find textarea in response: ".$content;
$agenda = $1;
like $agenda, qr{- Item 1\s+- Item 2}ms, 'starting with empty template in public agenda';
like $agenda, qr{\[ZOOM LINK\]}, 'zoom link slug is present';
like $agenda, qr{\[MEETING DATE\]}, 'meeting date not set yet';

#
# make an edit
#
my $tomorrow = DateTime->from_epoch(epoch => $ENV{TEST_NOW} + 60*60*24)->ymd;
my $updated_agenda = "Agenda\nlink: [ZOOM LINK]\ndate: $tomorrow\nupdated agenda blah blah";
$res = $test->post('/board-agenda/edit', {
    meeting_date => $tomorrow,
    agenda_text => $updated_agenda,
});
ok $res->is_redirect, 'POST gave us a 303 redirect';
is $res->header('location'), '/board-agenda/edit', 'and the redirect is to /board-agenda/edit';

#
# fetch filled-in public agenda
#
$test->get_ok('/board-agenda');
$content = $test->content;
$content =~ m{<div id="public-meeting-agenda".*?>(.+?)</div>}ms
    or die "can't find public-meeting-agenda div in response: ".$content;
$agenda = $1;
like $agenda, qr{updated agenda blah blah}, 'updated agenda now being served';
like $agenda, qr{\[Zoom link available to board members\]}, 'no zoom link in public agenda';
unlike $agenda, qr{\[MEETING DATE\]}, 'meeting date slug is gone';
like $agenda, qr{date: $tomorrow}, 'meeting date is filled in';

#
# check out the endpoint for the copy-to-pastebuffer link
#
$test->get_ok('/board-agenda/email-text');
my $data = decode_json $test->content;
$agenda = $data->{text};
like $agenda, qr{updated agenda blah blah}, 'for paste: updated agenda now being served';
like $agenda, qr{link: https://zoom.us/whatever}, 'for paste: zoom link is filled in';
unlike $agenda, qr{\[MEETING DATE\]}, 'for paste: meeting date slug is gone';
like $agenda, qr{date: $tomorrow}, 'for paste: meeting date is filled in';

#
# advance the date past the meeting date and what's served will reset
#
$ENV{TEST_NOW} = 1651112285 + 60*60*24*3;
$test->get_ok('/board-agenda');
$content = $test->content;
$content =~ m{<div id="public-meeting-agenda".*?>(.+?)</div>}ms
    or die "can't find public-meeting-agenda div in response: ".$content;
$agenda = $1;
like $agenda, qr{- Item 1\s+- Item 2}ms, 'back to empty template agenda';
like $agenda, qr{\[MEETING DATE\]}, "the next meeting date isn't set yet";

