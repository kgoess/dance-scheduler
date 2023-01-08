=head1 NAME

bacds::Scheduler::FederatedAuth - handles various authentication realms

=head1 SYNOPSIS

We have these endpoints configured:

    post '/whatever-signin' => sub {
        my $jwt = params->{access_token}
            or send_error 'missing parameter "access_token"' => 400;

        my ($res, $err) = bacds::Scheduler::FederatedAuth
            ->check_whatever_auth($access_token);

        if ($err) {
            my ($code, $msg) = @$err;
            send_error $msg => $code;
        }

        cookie "WhateverToken" => $jwt, expires => "72 hours";
        cookie "LoginMethod" => 'whatever';
        redirect '/' => 303;
    };

And individual endpoints have their authorization protected like this, where
the "can_edit_event" checks those cookies.

    put '/event/:event_id' => can_edit_event sub {
         my $event = $event_model->put_row(params);



=head1 DESCRIPTION

We have a signin.html page with a Google button, a Facebook button, and a
regular email/password/submit form. The latter is only for people who have
access to the database table on our server, so that we don't have to implement
an entire forgot-my-password flow and everything else a password form would
entail (like a Captcha even).

The implementation of all those authentications is here.

=cut

package bacds::Scheduler::FederatedAuth;

use 5.16.0;
use warnings;

use Crypt::JWT qw/decode_jwt/;
use Crypt::CBC;
use Data::Dump qw/dump/;
use Data::Entropy::Algorithms qw(rand_bits); # recommended by Digest::Bcrypt
use Data::UUID;
use Digest;
use Facebook::OpenGraph;
use Furl;
use HTTP::Request::Common;
use JSON::MaybeXS qw/decode_json/;
use LWP::UserAgent;
use MIME::Base64 qw/encode_base64url decode_base64url/;
use String::Random;

use bacds::Scheduler::Util::Db qw/get_dbh/;

=head2 check_google_auth

See the /google-signin route in bacds::Scheduler.

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

    my $dbh = get_dbh();

    my $rs = $dbh->resultset('Programmer')->search({
         email => $decoded->{email}
    });

    my $programmer = $rs->first
        or return undef, [401, "No programmer found for '$decoded->{email}'"];
    $programmer->is_deleted
         and return undef, [403, "The account for '$decoded->{email}' is deleted"];

    return $programmer;
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

=head2 check_facebook_auth

See the /facebook-signin route in bacds::Scheduler.

The response from Facebook's /me will look like this:

    {
      email => "knet\@goess.org",
      id => 10160221707369379,
      name => "Kevin Goess",
      picture => {
        data => {
          height => 50,
          is_silhouette => bless(do{\(my $o = 0)}, "JSON::PP::Boolean"),
          url => "https://platform-lookaside.fbsbx.com/p...",
          width => 50,
        },
      },
    }


=cut

sub check_facebook_auth {
    my ($class, $access_token) = @_;

    my $res;

    eval {
        my $ua = Furl::HTTP->new(
            timeout => 10
        );

        my $secret = _get_facebook_secret();

        my $fb = Facebook::OpenGraph->new({
            app_id => '430760472446636',
            secret => $secret,
            version => 'v14.0',
            ua => $ua,
            access_token => $access_token,
            #namespace =>
            #redirect_uri
        });

        $res = $fb->get('/me?locale=en_US&fields=name,email,picture');
    };
    if ($@) {
        return undef, [400, $@];
    }

    if (!ref $res) {
        return undef, [401, 'Login failed'];
    }

    my $dbh = get_dbh();
    # This had been using:
    #     my $rows = bacds::Scheduler::Model::Programmer->get_multiple_rows({
    # but that is more verbose, we don't want multiple rows, and we want
    # a Programmer object we can call methods on, not a generic hash
    # (for which a mis-typed key can silently fail to give you data).
    # I think we should change google to just use ->search as well.
    my $rs = $dbh->resultset('Programmer')->search({
         email => $res->{email}
    });

    my $programmer = $rs->first
        or return undef, [401, "No programmer found for '$res->{email}'"];
    $programmer->is_deleted
         and return undef, [403, "The account for '$res->{email}' is deleted"];

    return $programmer;
}

sub _get_facebook_secret {
    if ($ENV{HOME} && -e "$ENV{HOME}/.facebook-secret") {
        open my $fh, '<', "$ENV{HOME}/.facebook-secret"
            or die "can't read $ENV{HOME}/.facebook-secret: $!";
        my $secret = <$fh>;
        chomp $secret;
        return $secret;
    }

    my $system_path = '/var/www/bacds.org/dance-scheduler/private/facebook-secret';
    if (-e $system_path) {
        open my $fh, '<', $system_path
            or die "can'e read $system_path: $!";
        my $secret = <$fh>;
        chomp $secret;
        return $secret;
    }
    die "please put the Facebook API secret into either ~/.facebook-secret or $system_path"
}

=head2 check_bacds_auth

Compare the incoming email+password to the database and return ($email, $err).

=cut

sub check_bacds_auth {
    shift if $_[0] eq __PACKAGE__;
    my ($email_param, $password_param) = @_;

    my $dbh = get_dbh();
    my $rs = $dbh->resultset('Programmer')->search({
        email => $email_param
    });

    my $programmer = $rs->first
        or return undef, [401, "No programmer found for '$email_param'"];
    $programmer->is_deleted
         and return undef, [403, "The account for '$email_param' is deleted"];
    $programmer->password_hash or return undef, [403,
         'Please use google or facebook to login, or ask bacds-web-committee@ about dance-scheduler-user-password.pl'
    ];

    # We're being an oracle. Should return something more vague? Meh.
    password_matches($password_param, $programmer->password_hash)
         or return undef, [401, 'Incorrect password'] ;

    return $programmer->email;
}

=head2 password_matches

Returns boolean checking that the incoming pw parameter
jibes with the entry in the database of "$alg=$salt=$hash"

=cut

sub password_matches {
    shift if $_[0] eq __PACKAGE__;
    my ($pw_param, $existing_pw_data) = @_;

    my ($alg, $data) = split /=/, $existing_pw_data, 2;
    if ($alg eq 'bcrypt') {
        my ($salt_b64, $existing_b64) = split /=/, $data, 2;
        my $salt = decode_base64url($salt_b64);

        my $bcrypt = Digest->new('Bcrypt', cost => 12, salt => $salt);
        $bcrypt->add($pw_param);
        return $bcrypt->b64digest eq $existing_b64;
    }
}

=head2 make_password_entry

We'll store the passwords as:

    'bcrypt=$salt=$hash

See https://cheatsheetseries.owasp.org/cheatsheets/Password_Storage_Cheat_Sheet.html and perldoc Digest::Bcrypt

=cut
sub make_password_entry {
    shift if $_[0] eq __PACKAGE__;
    my ($password) = @_;

    my $salt = rand_bits(16*8);
    my $bcrypt = Digest->new('Bcrypt', cost => 12, salt => $salt);
    $bcrypt->add($password);
    my $salt_b64 = encode_base64url($salt);
    return join '=', 'bcrypt', $salt_b64, $bcrypt->b64digest;
}

sub cipher {
    state $cipher = Crypt::CBC->new(
        -pass => _get_session_encryption_key(),
        -cipher => 'Crypt::Blowfish',
        -pbkdf => 'pbkdf2',
    );
    return $cipher;
}

=head2 create_session_cookie

If they login with the email/password/submit form, we'll create this session
cookie and check it on subsequent protected requests.

=cut

sub create_session_cookie {
    my ($class, $email) = @_;

    my $cookie = join $;,
        'v1',
        $email,
        'this-is-bacds',
        String::Random->new->randpattern('.'x128),
    ;

    return encode_base64url cipher()->encrypt($cookie);
}

=head2 check_session_cookie

This checks the cookie we created if they logged in with our
email/password/submit form (as opposed to the Facebook and Google buttons).

=cut

sub check_session_cookie {
    my ($class, $session_cookie) = @_;

    my $programmer;

    eval {
        my $session_str = cipher()->decrypt(decode_base64url $session_cookie);
        my ($version, $email, $canary, $nonce) = split /$;/, $session_str;
        ($version//'') eq 'v1' or die "version looks funny: $session_str";
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
        return undef, $@;
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
        # this just hits an SELinux error, I'll do it by hand
        open my $fh, ">", $system_key_file
            or die "can't create $system_key_file: $!";
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
