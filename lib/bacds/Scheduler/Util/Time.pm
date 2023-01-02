=head1 NAME

bacds::Scheduler::Util::Time - some time utilities

=head1 SYNOPSIS

use bacds::Scheduler::Util::Time qw/get_now get_today/;

    say get_now->iso8601; # in GMT

    say get_today->ymd; # returns 2022-01-01 on the first even after 4pm PST

    $ENV{TEST_NOW} = 1672676524; # make dates repeatable in unit tests

=cut

package bacds::Scheduler::Util::Time;

use 5.16.0;
use warnings;

use Dancer2;
use DateTime;
use Data::Dump qw/dump/;

use Exporter 'import';
our @EXPORT_OK = qw/
    get_now
    get_today
/;

=head2 get_now

Returns a DateTime object for "now" in GMT, but respects $ENV{TEST_NOW} for
unit tests.

=cut

sub get_now{
    return $ENV{TEST_NOW}
        ? DateTime->from_epoch(epoch => $ENV{TEST_NOW})
        : DateTime->now();
};

=head2 get_today

Returns DateTime object with a "floating" timezone, suitable for calling
$dt->ymd on to get today's calendar date. So it'll still be the correct date
for today even if it's tomorrow in Greenwich.

See https://metacpan.org/pod/DateTime#Making-Things-Simple

=cut

sub get_today {

    my $dt = $ENV{TEST_NOW}
        ? DateTime->from_epoch(epoch => $ENV{TEST_NOW}, time_zone => 'local')
        : DateTime->now(time_zone => 'local');

    $dt->set_time_zone('floating');

    return $dt;
}

true;
