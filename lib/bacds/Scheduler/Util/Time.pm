package bacds::Scheduler::Util::Time;

use 5.16.0;
use warnings;

use Dancer2;
use DateTime;
use Data::Dump qw/dump/;

use Exporter 'import';
our @EXPORT_OK = qw/get_now/;

sub get_now{
    return $ENV{TEST_NOW}
        ? DateTime->from_epoch(epoch => $ENV{TEST_NOW})
        : DateTime->now();
};

true;
