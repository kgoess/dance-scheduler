=head1 NAME

bacds::Scheduler::Util::Initialize - initialize code for the web server

=head1 DESCRIPTION

The dance-scheduler app needed a way to force the user to reload if we were
coding javascript out from under it, so this does a checksum of the installed
javascript to see if any of it has changed. So bin/app.psgi runs initialize on
startup and stores the checksum. The front page of the dance-scheduler app at /
sets a cookie with the checksum. Then any endpoint in Scheduler.pm that has
"requires_checksum" checks the cookie and if the client's checksum is old it
returns a message to the app to force a reload.

This isn't used by the bacds.org website at all.

=cut

package bacds::Scheduler::Util::Initialize;
use 5.16.0;
use warnings;
use Digest::SHA;
use File::Find;
use Dancer2;

our $checksum;

sub initialize{
    my ($class) = @_;

    my $sha = Digest::SHA->new(256);

    find(
        sub {
            # unnecessary to checksum images
            return if $File::Find::name =~ m{/images/};
            # seems like a waste of time loading bootstrap stuff that hardly ever changes
            return if $File::Find::name =~ m{/css/scss/bootstrap/};
            return if $File::Find::name =~ m{/css/bootstrap-.+?-dist/css/};
            return if $File::Find::name =~ m{/css/bootstrap-5.3.2-dist/js/};
            return if $File::Find::name =~ m{/fonts/};
            return unless -f $File::Find::name;
            if (!-r $File::Find::name) {
                warn "can't read $File::Find::name";
                return;
            }

            open my $fh, "<", $File::Find::name or do {
                warn "couldn't open file $File::Find::name for reading $!";
                return;
            };
            close $fh;
            eval {
                $sha->addfile($File::Find::name);
            };
            if ($@) {
                warn "Digest::SHA->addfile couldn't read file $File::Find::name: $!";
                return;
            }
        },
        config->{'public_dir'}
    );

    $checksum = $sha->hexdigest;
}

sub get_checksum{
    if (!$checksum) {
        initialize();
    }
    return $checksum;
}

1;
