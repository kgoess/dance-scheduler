# Tests for bacds::Scheduler::RateLimit and the limits on /bacds-signin and
# /unearth/member/request-link

use 5.32.1;
use warnings;

use Data::Dump qw/dump/;
use DateTime;
use HTTP::Request::Common;
use Test::More tests => 37;
use Test::Warn;

use bacds::Scheduler;
use bacds::Scheduler::CiviCRM;
use bacds::Scheduler::FederatedAuth;
use bacds::Scheduler::RateLimit;
use bacds::Scheduler::Util::Db qw/get_dbh/;
use bacds::Scheduler::Util::Test qw/setup_test_db get_tester/;

setup_test_db;

my $RL     = 'bacds::Scheduler::RateLimit';
my $Limits = \%bacds::Scheduler::RateLimit::Limits;
my $dbh    = get_dbh();

bacds::Scheduler::set(member_portal_base_url => 'https://bacds.example.org/dance-scheduler');

# mock CiviCRM: every email belongs to contact 42
my @magic_links;
{
    no warnings 'redefine';
    *bacds::Scheduler::CiviCRM::new = sub { bless {}, shift };
    *bacds::Scheduler::CiviCRM::find_member_contacts_by_email = sub {
        return [{ contact_id => 42, display_name => 'Alice', email => 'alice@example.com' }];
    };
    *bacds::Scheduler::CiviCRM::send_magic_link_email = sub {
        my ($self, $contact_id) = @_;
        push @magic_links, $contact_id;
    };
}

# the routes warn about every refusal and failure; collect them instead
my @warnings;
$SIG{__WARN__} = sub { push @warnings, @_ };

sub clear_events { $dbh->resultset('RateLimitEvent')->delete }

test_hit_and_over_limit();
test_window();
test_prune();
test_fails_open();
test_bacds_signin();
test_request_link_per_ip();
test_request_link_per_contact();
test_old_tokens_deleted();

sub test_hit_and_over_limit {
    clear_events();
    local $Limits->{member_link_ip} = { max => 2, window => 3600 };

    ok !$RL->hit(member_link_ip => '10.0.0.1'), 'first hit allowed';
    ok !$RL->hit(member_link_ip => '10.0.0.1'), 'second hit allowed';
    ok  $RL->hit(member_link_ip => '10.0.0.1'), 'third hit refused';
    is $dbh->resultset('RateLimitEvent')->count, 2, "the refused hit wasn't recorded";

    ok !$RL->over_limit(member_link_ip => '10.0.0.2'), 'other keys are counted separately';
    ok !$RL->over_limit(signin_fail_ip => '10.0.0.1'), 'other buckets are counted separately';

    local $Limits->{signin_fail_email} = { max => 1, window => 3600 };
    $RL->record(signin_fail_email => ' Alice@Example.COM ');
    ok $RL->over_limit(signin_fail_email => 'alice@example.com'),
        'keys ignore case and surrounding space';

    eval { $RL->hit(no_such_bucket => 'x') };
    like $@, qr{unknown rate limit bucket 'no_such_bucket'}, 'a typo in a bucket name dies';
}

sub test_window {
    clear_events();
    local $Limits->{member_link_ip} = { max => 1, window => 3600 };

    $dbh->resultset('RateLimitEvent')->create({
        bucket     => 'member_link_ip',
        event_key  => '10.0.0.1',
        created_ts => DateTime->now->subtract(minutes => 61),
    });
    ok !$RL->over_limit(member_link_ip => '10.0.0.1'), 'events older than the window are ignored';

    $dbh->resultset('RateLimitEvent')->create({
        bucket     => 'member_link_ip',
        event_key  => '10.0.0.1',
        created_ts => DateTime->now->subtract(minutes => 59),
    });
    ok $RL->over_limit(member_link_ip => '10.0.0.1'), 'events inside the window count';
}

sub test_prune {
    clear_events();
    my $rs = $dbh->resultset('RateLimitEvent');
    $rs->create({ bucket => 'member_link_ip', event_key => 'old',
                  created_ts => DateTime->now->subtract(hours => 25) });
    $rs->create({ bucket => 'member_link_ip', event_key => 'new',
                  created_ts => DateTime->now->subtract(hours => 23) });

    $RL->prune;
    is_deeply [ map $_->event_key, $rs->all ], ['new'], 'prune deletes events over a day old';
}

sub test_fails_open {
    no warnings 'redefine';
    local *bacds::Scheduler::RateLimit::get_dbh = sub { die "database is down\n" };

    my $over;
    warning_like { $over = $RL->over_limit(member_link_ip => '10.0.0.1') }
        qr{over_limit\(member_link_ip\) failed, allowing the request: database is down},
        'a database error warns';
    ok !$over, '...and lets the request through';

    warning_like { $RL->record(member_link_ip => '10.0.0.1') }
        qr{record\(member_link_ip\) failed: database is down},
        'record warns instead of dying';
}

sub test_bacds_signin {
    clear_events();
    local $Limits->{signin_fail_email} = { max => 3, window => 900 };
    local $Limits->{signin_fail_ip}    = { max => 5, window => 3600 };

    $dbh->resultset('Programmer')->create({
        name          => 'Pat Password',
        email         => 'pat@example.com',
        password_hash => bacds::Scheduler::FederatedAuth->make_password_entry('right'),
        is_superuser  => 0,
        is_deleted    => 0,
    });

    my $test = get_tester(checksum => 0);
    my $res;

    $res = $test->request(POST '/bacds-signin',
        { programmer_email => 'pat@example.com', password => 'wrong' });
    is $res->code, 401, 'wrong password gets a 401';
    my $wrong_password_page = $res->content;
    like $wrong_password_page, qr{Incorrect email or password}, 'with the generic message';

    $res = $test->request(POST '/bacds-signin',
        { programmer_email => 'nobody@example.com', password => 'wrong' });
    is $res->code, 401, 'unknown email gets a 401 too';
    is $res->content, $wrong_password_page, "the page doesn't say the email has no account";
    like $warnings[-1], qr{No programmer found for 'nobody\@example.com'},
        'the real reason is logged';

    $test->request(POST '/bacds-signin',
        { programmer_email => 'pat@example.com', password => 'wrong' }) for 1 .. 2;

    $res = $test->request(POST '/bacds-signin',
        { programmer_email => 'pat@example.com', password => 'right' });
    is $res->code, 429, 'after 3 failures for the email, even the right password is refused';
    like $res->content, qr{Too many failed logins}, 'with a message to wait';
    like $warnings[-1], qr{bacds-signin throttled for pat\@example.com from 127.0.0.1},
        'and the throttle is logged';

    # 4 failures from this IP so far; the refused request above isn't counted
    $res = $test->request(POST '/bacds-signin',
        { programmer_email => 'nobody@example.com', password => 'wrong' });
    is $res->code, 401, 'another email from the same IP still gets checked (5th IP failure)';

    $res = $test->request(POST '/bacds-signin',
        { programmer_email => 'another@example.com', password => 'wrong' });
    is $res->code, 429, 'after 5 failures from the IP, any email is refused';

    clear_events(); # as if the window had passed
    $res = $test->request(POST '/bacds-signin',
        { programmer_email => 'pat@example.com', password => 'right' });
    is $res->code, 303, 'once the failures age out, the right password works';
    is $dbh->resultset('RateLimitEvent')->count, 0, "a successful login isn't counted";
}

sub test_request_link_per_ip {
    clear_events();
    local $Limits->{member_link_ip}      = { max => 2,    window => 3600 };
    local $Limits->{member_link_contact} = { max => 1000, window => 3600 };
    @magic_links = ();

    my $test = get_tester(checksum => 0);
    my $res;
    for my $i (1 .. 2) {
        $res = $test->request(POST '/unearth/member/request-link', { email => 'alice@example.com' });
        like $res->content, qr{Check Your Email}, "request $i shows the confirmation page";
    }
    is scalar(@magic_links), 2, 'and both sent a link';

    $res = $test->request(POST '/unearth/member/request-link', { email => 'alice@example.com' });
    like $res->content, qr{Check Your Email}, 'over the IP limit still shows the confirmation page';
    is scalar(@magic_links), 2, "but doesn't send a link";
    like $warnings[-1], qr{request_link throttled for alice\@example.com from 127.0.0.1},
        'and logs it';
}

sub test_request_link_per_contact {
    clear_events();
    local $Limits->{member_link_ip}      = { max => 1000, window => 3600 };
    local $Limits->{member_link_contact} = { max => 2,    window => 3600 };
    @magic_links = ();

    my $test = get_tester(checksum => 0);
    $test->request(POST '/unearth/member/request-link', { email => 'alice@example.com' }) for 1 .. 3;
    is scalar(@magic_links), 2, 'only 2 links sent to the same contact';
    like $warnings[-1], qr{too many links sent to contact 42}, 'the third was logged and skipped';
    is $dbh->resultset('MemberToken')->search({ civicrm_contact_id => 42 })->count,
        $dbh->resultset('MemberToken')->count,
        'sanity check: all tokens are for contact 42';
}

sub test_old_tokens_deleted {
    clear_events();
    local $Limits->{member_link_ip}      = { max => 1000, window => 3600 };
    local $Limits->{member_link_contact} = { max => 1000, window => 3600 };

    my $now = DateTime->now;
    my $tokens = $dbh->resultset('MemberToken');
    $tokens->delete;
    $tokens->create({
        token => 'a' x 64, civicrm_contact_id => 7,
        created_ts => $now->clone->subtract(days => 3),
        expires_ts => $now->clone->subtract(days => 2),
    });
    $tokens->create({
        token => 'b' x 64, civicrm_contact_id => 7,
        created_ts => $now->clone->subtract(hours => 3),
        expires_ts => $now->clone->subtract(hours => 2),
    });

    get_tester(checksum => 0)->request(POST '/unearth/member/request-link',
        { email => 'alice@example.com' });

    ok !$tokens->find({ token => 'a' x 64 }), 'a token that expired 2 days ago was deleted';
    ok  $tokens->find({ token => 'b' x 64 }), 'a token that expired 2 hours ago is kept';
}
