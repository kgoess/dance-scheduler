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
                warn "Digest::SHA couldn't read file $File::Find::name: $!";
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
