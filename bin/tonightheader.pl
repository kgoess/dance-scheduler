#!/usr/bin/env perl
#
# This is a quick replacement for the old tonightheader.pl run from
# make-frontpage.files.sh.
# This approach is silly because it takes 700ms to run, just loading
# all the libraries. It would be quicker to make an HTTP endpoint that
# just returns the count. Or better yet to encapsulate all the
# tonightheader stuff in one file, or a dancer2 http endpoint.

use warnings;
use 5.16.0;

use bacds::Scheduler::Util::Db qw/get_dbh/;
use bacds::Scheduler::Util::Time qw/get_today/;


my $count = get_count_for_today();
my $plural = $count > 1 ? "s" : "";

if ($count) {
    print "<h2>Today's Dance$plural:</h2>\n";
    # look for "div.tonight" style in /css/base.css for styling
    print '<div class="tonight">', "\n";
} else {
    print '<div class="tonight">', "\n";
    print "<h2>No dances tonight</h2>\n";
}



sub get_count_for_today {
    my $dbh = get_dbh(
        db => 'schedule',
        user => 'scheduler',
        #debug  => 1,
    );

    my $today = get_today->ymd;
    my $tomorrow = get_today->add(days => 1)->ymd;

    my $count = $dbh->resultset('Event')->count({
        start_date => { '>=', $today, '<', $tomorrow },
        is_deleted => 0,
    },{
        order_by => 'start_date',
    });
    return $count;
}

