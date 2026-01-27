
use 5.32.1;
use warnings;
use feature 'signatures';
no warnings "experimental::signatures";

use File::Basename qw/dirname/;
use Test::More tests => 5;

use bacds::Scheduler::WeeklyEmailQueue qw/QUEUE_DIRNAME/;

my $basedir = dirname($0)."/testqueue";
mkdir $basedir or die "can't create $basedir $!";
my $queuedir = "$basedir/".QUEUE_DIRNAME;
mkdir $queuedir or die "can't create $queuedir $!";
mkdir "$queuedir/old" or die "can't create $queuedir/old $!";

END {
    return unless $queuedir; # don't "rm /" :-(
    if (`ls $queuedir/old`) {
        `rm $queuedir/old/*`;
    }
    rmdir "$queuedir/old";
    if (`ls $queuedir`) {
        `rm $queuedir/*`;
    }
    rmdir $queuedir;
    rmdir $basedir;
}

basic_test($basedir);

sub basic_test ($basedir) {
    my $queuedir = "$basedir/".QUEUE_DIRNAME;
    open my $fh, ">", "$queuedir/file1.md";
    print $fh <<EOL;
this is first entry
---------------
EOL
    close $fh;

    open $fh, ">", "$queuedir/file2.md";
    print $fh <<EOL;
second entry with a url
---------------
This is an [example link](http://example.com/).
EOL
    close $fh;

    my $q = bacds::Scheduler::WeeklyEmailQueue->new(
        basedir => $basedir,
    );
    $q->init();

    my ($html, $text);

    ($html, $text) = $q->get_next;
    is $html, <<EOL;
<h2>this is first entry</h2>
EOL
    is $text, <<EOL;
this is first entry
---------------
EOL

    ($html, $text) = $q->get_next;
    is $html, <<EOL;
<h2>second entry with a url</h2>

<p>This is an <a href="http://example.com/">example link</a>.</p>
EOL
    is $text, <<EOL;
second entry with a url
---------------
This is an [example link](http://example.com/).
EOL

    $q->mark_all_done;

    opendir my $dirh, $queuedir or die "can't opendir $queuedir $!";
    my @found;
    while (my $entry = readdir($dirh)) {
        next if $entry =~ /^\./;
        next if $entry =~ /README/;
        next if $entry eq 'old';
        push @found, $entry;
    }
    is @found, 0, "no files found in $queuedir: @found";
}
