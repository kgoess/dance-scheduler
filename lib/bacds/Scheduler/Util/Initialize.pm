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
            $sha->addfile($File::Find::name);
        },
        config->{'public_dir'}
    );

    $checksum = $sha->hexdigest;
}

sub get_checksum{
    return $checksum;
}

1;
