=head1 NAME

bacds::Scheduler::WeeklyEmailQueue - manages extra news blurbs for bin/send-weekly-schedule.pl

=head1 SYNOPSIS

    my $q = bacds::Scheduler::WeeklyEmailQueue->new(
        basedir => $basedir,
    );
    $q->init;
    my (@news_html, @news_text);
    while (my ($html, $text) = $q->get_next) {
        ...do something
    }
    $q->mark_all_done; # moves to "old/"

=head1 DESCRIPTION

The files in /var/lib/dance-scheduler/weekly-email-queue/ are
"markdown", see https://daringfireball.net/projects/markdown/.
We'll convert them to HTML for you for the HTML part of the
email. The markdown itself will be the text part of the email.

After calling $q->mark_all_done they'll be moved into the "old/"
subdirectory of that queuedir so that they won't be send again
next week.

=cut

package bacds::Scheduler::WeeklyEmailQueue;

use 5.32.1;
use warnings;
use feature 'signatures';

use Data::Dump qw/dump/;
use File::Copy qw/move/;
use Moo;
use Text::Markdown qw/markdown/;

# has to come after 'use Moo'
no warnings "experimental::signatures";

use constant QUEUE_DIRNAME => 'weekly-email-queue';

use Exporter 'import';
our @EXPORT_OK = qw(QUEUE_DIRNAME);


has basedir => (
    is => 'ro',
    default => '/var/lib/dance-scheduler',
);

has _queue => (
    is => 'ro',
    default => sub { [] },
);

has _filenames => (
    is => 'ro',
    default => sub { [] },
);

has _init_done => (
    is => 'rw',
    default => 0,
);

sub init ($self) {
    my $basedir = $self->basedir;

    if ($self->_init_done) {
        die "you already called $self->init. You need to make a new one";
    }
        

    my $queuedir = "$basedir/".QUEUE_DIRNAME;

    if (! -e $queuedir) {
        die "$queuedir does not exist, skipping";
    }
    if (! -w $queuedir) {
        die "This user uid:$< gid:$( needs write access to $queuedir to continue";
    }
    if (! -e "$queuedir/old") {
        die "please mkdir $queuedir/old before continuing";
    }
    if (! -w "$queuedir/old") {
        die "This user uid:$< gid:$( needs write access to $queuedir/old to continue";
    }

    opendir my $dirh, $queuedir or die "can't opendir $queuedir $!";

    my @entries = readdir($dirh);
    foreach my $entry (sort @entries) {
        next if $entry =~ /^\./;
        next if $entry =~ /^README/;
        my $fullpath = "$queuedir/$entry";
        next if -d $fullpath;
        open my $fh, "<", $fullpath or die "can't read $fullpath $!";
        my $markdown = join '', <$fh>;

        push $self->_filenames->@*, $entry;
        push $self->_queue->@*, $markdown;
    } 

    $self->_init_done(1);
}

=head2 get_next

Returns ($html, $text);

=cut;

sub get_next ($self) {
    if (! $self->_init_done) {
        die "you need to call $self->init first or this won't end well";
    }

    my $text = shift($self->_queue->@*)
        or return;

    my $html = markdown($text);

    return $html, $text;
}

=head2 mark_all_done

Moves all the filenames into $basedir/old/

=cut

sub mark_all_done ($self) {
    my $basedir = $self->basedir;
    my $queuedir = "$basedir/".QUEUE_DIRNAME;
    foreach  my $entry ($self->_filenames->@*) {
        my $fullpath = "$queuedir/$entry";
        my $savepath = "$queuedir/old/$entry";
        move $fullpath, $savepath or die "mv $fullpath $savepath failed: $!";
    }
}

1;
    

