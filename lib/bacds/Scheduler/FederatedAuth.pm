package bacds::Scheduler::FederatedAuth;

use 5.16.0;
use warnings;

use Crypt::JWT qw/decode_jwt/;
use Crypt::CBC;
use Data::UUID;
use HTTP::Request::Common;
use JSON::MaybeXS qw/decode_json/;
use LWP::UserAgent;
use MIME::Base64 qw/encode_base64 decode_base64/;
use String::Random;

use bacds::Scheduler::Util::Db qw/get_dbh/;

=head2 check_google_auth

See notes on https://metacpan.org/pod/Crypt::JWT

Returns ($programmer, $err), with only one of those populated.

$programmer will be a bacds::Scheduler::Schema::Result::Programmer

$err would be [403, "no such user"]

See

https://developers.google.com/identity/gsi/web/guides/overview

https://developers.google.com/identity/gsi/web/guides/display-button

=cut

sub check_google_auth {
    my ($class, $jwt) = @_;

    my $oauth_keys = fetch_google_oauth_keys()
        or return undef, [500, 'fetching google keys failed'];

    my $decoded;

    eval {
        $decoded = decode_jwt(
            token => $jwt,
            kid_keys => $oauth_keys,
            verify_iss => 'https://accounts.google.com',
            verify_aud => '1098017941996-inv98s0als8ikk474e2tm6b2necuna1g.apps.googleusercontent.com',
            # decode_payload: undef means: if possible decode payload from JSON
            # string, if decode_json fails return payload as a raw string (octets).
            decode_payload => undef,
        );

        # $decoded will be something like this:
        # {
        #   aud => "10980171111-inv98s0als8ikk474e2xxx.apps.googleusercontent.com",
        #   azp => "10980172222-inv98s0als8ikk474xxx.apps.googleusercontent.com",
        #   email => 'homer@springfield.com',
        #   email_verified => bless(do{\(my $o = 1)}, "JSON::PP::Boolean"),
        #   exp => 1659321752,
        #   family_name => "Simpson",
        #   given_name => "Homer",
        #   iat => 1659318152,
        #   iss => "https://accounts.google.com",
        #   jti => "f219eacca83f763e900b292e4d6740dffbb7b449",
        #   name => "Homer Simpson",
        #   nbf => 1659317852,
        #   picture => "https://lh3.googleusercontent.com/a-/AFdZxxx",
        #   sub => "114402625298334512345",
        # }
    };
    if (my $err = $@) {
        $err =~ s/ at .+//;
        return undef, [400, $err];
    }

    if (!ref $decoded) {
        return undef, [401, 'Login failed'];
    }

    my $programmer_model = '';
    my $rows = bacds::Scheduler::Model::Programmer->get_multiple_rows({
         email => $decoded->{email}
    });

    if (!@$rows) {
        return undef, [401, "We don't recognize $decoded->{email} in our system"];
    }

    return $rows->[0];
}

=head2 fetch_google_oauth_keys

Fetching from https://www.googleapis.com/oauth2/v2/certs per notes on
use HTTP::Request::Common;

=cut

sub fetch_google_oauth_keys {

    my $min_acceptable_age = time() - 60*60*24;

    my $cache_dir = $ENV{TEST_CACHE_PATH} || '/var/cache/httpd/dance-scheduler';
    my $path = "$cache_dir/google-oauth-keys.json";

    my $json;

    if (! -e $path || (stat($path))[9] < $min_acceptable_age) {
        $json = refresh_google_oauth_keys($cache_dir, $path);

    } else {
        open my $fh, "<", $path or do {
            warn "can't read google oauth keys from $path: $!";
            return;
        };
        $json = join '', <$fh>;
    }

    if (!$json) {
        warn "unable to fetch google_auth_keys";
        return;
    }

    return decode_json $json;
}

sub refresh_google_oauth_keys {
    my ($cache_dir, $path) = @_;

    if (! -e $cache_dir) {
        mkdir $cache_dir or do {
            warn "can't mkdir $cache_dir: $!";
            return;
        }
    }

    my $ua = LWP::UserAgent->new;
    my $url = 'https://www.googleapis.com/oauth2/v2/certs';
    my $response = $ua->request(GET $url);

    my $json;

    if (! $response->is_success) {
        warn "failed to GET $url: ". $response->status_line;
        return;
    } else {
        $json = $response->decoded_content;
        open my $fh, ">", $path or do {
                warn "can't write to $path: $!";
                return;
            };
        print $fh $json;
    }
    return $json;
}

sub cipher {
    state $cipher = Crypt::CBC->new(
        -pass => _get_session_encryption_key(),
        -cipher => 'Crypt::Blowfish',
        -pbkdf => 'pbkdf2',
    );
    return $cipher;
}

sub create_session_cookie {
    my ($class, $email) = @_;

    state $rand =
    my $cookie = join $;,
        'v1',
        $email,
        'this-is-bacds',
        String::Random->new->randpattern('.'x128),
    ;

    return encode_base64 cipher()->encrypt($cookie);
}

sub check_session_cookie {
    my ($class, $session_cookie) = @_;

    my $programmer;

    eval {
        my $session_str = cipher()->decrypt(decode_base64 $session_cookie);
        my ($version, $email, $canary, $nonce) = split /$;/, $session_str;
        $version eq 'v1' or die "version looks funny: $session_str";
        # not sure this is necessary, but seems helpful
        $canary eq 'this-is-bacds' or die "canary looks funny: $session_str";
        length $nonce == 128 or die "nonce wrong length: $session_str";

        my $dbh = get_dbh();
        my $rs = $dbh->resultset('Programmer')->search({
            email => $email
        });
        $programmer = $rs->first or die "no programmer found for '$email'";
    };
    if ($@) {
        warn "check_login_str: $@";
        return undef;
    }
    return $programmer;
}

# I'm copying this from bacds::Scheduler::Util::Db->_get_password
# but they should both be cleaned-up/combined, whatever,
# see the perldoc Dancer2::Config notes in _get_password
my $_session_encryption_key;
sub _get_session_encryption_key {
    return $_session_encryption_key if $_session_encryption_key;

    my $system_key_file = '/var/www/bacds.org/dance-scheduler/private/session-encryption-key';
    my $user_key_file = $ENV{HOME} ? "$ENV{HOME}/.session-encryption-key" : undef;

    if (-r $system_key_file) {
        open my $fh, "<", $system_key_file
            or die "can't read $system_key_file: $!";
        $_session_encryption_key = <$fh>;
        chomp $_session_encryption_key;
    } elsif (!$ENV{HOME}) {
        open my $fh, ">", $system_key_file
            or die "can't create to $system_key_file: $!";
        $_session_encryption_key = Data::UUID->new->create_b64;
        print $fh $_session_encryption_key;
        close $fh;
    } elsif ($user_key_file and -e $user_key_file) {
        open my $fh, "<", $user_key_file
            or die "can't read $user_key_file: $!";
        $_session_encryption_key = <$fh>;
        chomp $_session_encryption_key;
    } else {
        open my $fh, ">", $user_key_file
            or die "cant create $user_key_file: $!";
        $_session_encryption_key = Data::UUID->new->create_b64;
        print $fh $_session_encryption_key;
        close $fh;
    }

    return $_session_encryption_key;
}

1;