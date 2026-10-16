# testing the session cookie from bacds::Scheduler::FederatedAuth, used for
# email/password and Facebook logins

use 5.16.0;
use warnings;

use Data::Dump qw/dump/;
use MIME::Base64 qw/encode_base64url decode_base64url/;
use Test::More tests => 13;

use bacds::Scheduler::FederatedAuth;
use bacds::Scheduler::Util::Db qw/get_dbh/;
use bacds::Scheduler::Util::Test qw/setup_test_db/;
setup_test_db;

my $class = 'bacds::Scheduler::FederatedAuth';

my $programmer = get_dbh()->resultset('Programmer')->create({
    name => 'Paul Programmer',
    is_superuser => 0,
    email => 'paul@programmer.com',
    is_deleted => 0,
});

my ($res, $err);

my $cookie = $class->create_session_cookie('paul@programmer.com');
($res, $err) = $class->check_session_cookie($cookie);
is $res && $res->email, 'paul@programmer.com', 'fresh cookie ok' or diag $err;

unlike decode_base64url($cookie), qr{paul}, "the cookie doesn't show the email";

# flip one bit in the ciphertext
my $raw = decode_base64url($cookie);
substr($raw, -1, 1) ^= "\x01";
my $tampered = encode_base64url($raw);
($res, $err) = $class->check_session_cookie($tampered);
ok !$res, 'tampered cookie rejected';
like $err, qr{^session cookie failed to decrypt}, 'tampered cookie error';
unlike $err, qr{\Q$tampered\E|paul}, "error doesn't show the cookie or email";

my $almost_expired = $class->create_session_cookie('paul@programmer.com',
    issued_at => time - 71 * 60 * 60);
($res, $err) = $class->check_session_cookie($almost_expired);
ok $res, 'cookie from 71 hours ago still ok' or diag $err;

my $expired = $class->create_session_cookie('paul@programmer.com',
    issued_at => time - 73 * 60 * 60);
($res, $err) = $class->check_session_cookie($expired);
ok !$res, 'cookie older than 72 hours rejected';
like $err, qr{has expired}, 'expired cookie error';

my $future = $class->create_session_cookie('paul@programmer.com',
    issued_at => time + 60 * 60);
($res, $err) = $class->check_session_cookie($future);
ok !$res, 'cookie issued in the future rejected';

($res, $err) = $class->check_session_cookie('not-a-cookie');
ok !$res, 'junk cookie rejected';

($res, $err) = $class->check_session_cookie(undef);
ok !$res, 'missing cookie rejected';

$programmer->update({ is_deleted => 1 });
($res, $err) = $class->check_session_cookie($cookie);
ok !$res, "deleted programmer's cookie rejected";
like $err, qr{is deleted}, 'deleted programmer error';
