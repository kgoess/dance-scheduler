
# tests for scripts in bin/
# just to make sure they at least kind of work
# (there should be much interesting logic in them)

use 5.16.0;
use warnings;

use Capture::Tiny qw/capture/;
use Test::More tests => 3;

use bacds::Scheduler::Util::Db qw/get_dbh/;
use bacds::Scheduler::Util::Test qw/setup_test_db/;
use bacds::Scheduler::Util::Time qw/get_now/;
setup_test_db;

my $dbh = get_dbh();

$ENV{PERL5LIB} = "./lib:$ENV{PERL5LIB}";

my $fixture = setup_fixture();

test_dancefinder($fixture);


sub setup_fixture {
    my $event1 = $dbh->resultset('Event')->new({
        name => 'test event 1',
        synthetic_name => 'test event 1 synthname',
        custom_url => 'http://custom-url/test-event-1',
        short_desc => 'big <b> dance party &#9786',
        start_date => get_now->ymd,
        start_time => '20:00',
    });
    $event1->insert;
    my $event2 = $dbh->resultset('Event')->new({
        name => 'test event 2',
        synthetic_name => 'test event 2 synthname',
        start_date => get_now->add(days => 2)->ymd,
        start_time => '20:00',
    });
    $event2->insert;
    return {
        event1 => $event1,
        event2 => $event2,
    };
}

sub test_dancefinder {
    # this is a very light test

    my $cmd = './bin/dancefinder.pl';
    my @args = ('--basedir', '.', '--days', 5);
    my ($stdout, $stderr, $exit) = capture {
        system( $cmd, @args );
    };

    die "ERROR: $stderr" if $exit;
    die "ERROR: $stderr" if $stderr;
 
    like $stdout, qr{<em>test event 1</em>};
    like $stdout, qr{big <b> dance party &\#9786};
    like $stdout, qr{<em>test event 2</em>};
}



