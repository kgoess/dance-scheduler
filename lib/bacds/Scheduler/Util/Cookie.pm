=head1 NAME

bacds::Scheduler::Util::Cookie - some cookie utilities

=head1 DESCRIPTION

We don't want the cookies to bleed over from the test environment on port :5000
to production, so if you're running as any user but "apache" then we'll prefix
your $USER to the cookie name.

=head1 EXPORTS

LoginMethod, LoginSession, GoogleToken

=cut

package bacds::Scheduler::Util::Cookie;

use 5.16.0;
use warnings;

use Exporter 'import';
our @EXPORT_OK = qw/LoginMethod LoginSession GoogleToken /;

sub LoginMethod()  { cookie_name('LoginMethod')  };
sub LoginSession() { cookie_name('LoginSession') };
sub GoogleToken()  { cookie_name('GoogleToken')  };

sub cookie_name {
    my ($s) = @_;
    if ($ENV{USER} eq 'apache') {
        return $s;
    } else {
        my $user = $ENV{USER} =~ s/[^a-zA-Z0-9]//r;
        return "$user-$s";
    }
}


1;
