
# This is a scratch script. I'd migrated the old data from 2021-2014 from the
# .csv database to mysql but had neglected to include the "comments" field.
#
# This goes back and collects the comments and adds them to short_desc, which
# up to now was the contents of "band", which might or might not be information
# about the band and musicians.
#
# Run like this, set the load_all_from_old_schema that you want and test with:
#
# YES_DO_PROD=0 perl -Ilib bin/fix-migrate-comments.pl  --dry-run 1
#
# and then really do the updates by reversing those two arguments, or whatever
# to suit.


use 5.16.0;
use warnings;

use Data::Dump qw/dump/;
use Getopt::Long;

use bacds::Model::Event;# the old CSV schema

use bacds::Scheduler::Util::Db qw/get_dbh/;

my $dbh = $ENV{YES_DO_PROD}
    ? get_dbh(db => 'schedule', user => 'scheduler')
    : get_dbh(db => 'schedule_test', user => 'scheduler_test');

my $dry_run = 1;
GetOptions('dry-run=i', => \$dry_run);

#my @old_events = bacds::Model::Event->load_all_from_old_schema(table => 'schedule2021_clean_for_migration');
#my @old_events = bacds::Model::Event->load_all_from_really_old_schema(table => 'schedule2020');
#my @old_events = bacds::Model::Event->load_all_from_really_old_schema(table => 'schedule2019');
#my @old_events = bacds::Model::Event->load_all_from_really_old_schema(table => 'schedule2018');
#my @old_events = bacds::Model::Event->load_all_from_really_old_schema(table => 'schedule2017');
#my @old_events = bacds::Model::Event->load_all_from_really_old_schema(table => 'schedule2016');
#my @old_events = bacds::Model::Event->load_all_from_really_old_schema(table => 'schedule2015');
#my @old_events = bacds::Model::Event->load_all_from_really_old_schema(table => 'schedule2014');

my %update;

foreach my $old_event (@old_events) {
    next unless $old_event->comments;

    if ($old_event->startday eq '2020-05-31') {
        my $for_update = $dbh->resultset('Event')->find(579);
        $update{$for_update->event_id} = $old_event->comments;
        next;
    }
    if ($old_event->startday eq '2020-11-13') {
        next if $old_event->comments eq 'Tentative';
        my $for_update = $dbh->resultset('Event')->find(684);
        $update{$for_update->event_id} = $old_event->comments;
        next;
    }

    my $rs = $dbh->resultset('Event')->search({
       start_date  => $old_event->startday,
    });

    my @matches = $rs->all;
    my $for_update;
    if (@matches == 0) {
        die "no matches for event ".dump($old_event);

    } elsif (@matches > 1) {
        say "----------------\ntoo many matches ".scalar(@matches)." for ";
        my $s = join "\n", map { "$_: ".$old_event->$_ } qw/startday type loc leader band comments /;
        say $s;
        foreach my $match (@matches) {
            my $old_type = $old_event->type;
            my $old_loc = $old_event->loc;
            my $old_leader = $old_event->leader;
            if ($match->synthetic_name eq "$old_type $old_loc $old_leader") {
                say "\tok ", join ', ', $match->event_id, $match->start_date->ymd, $match->synthetic_name;
                $for_update = $match;
            } else {
                say "\tskipping ", join ', ', $match->event_id, $match->start_date->ymd, $match->synthetic_name;
            }
        }
        say "---------------\n";
    } else {
        say "ok: ".$matches[0]->synthetic_name;
        $for_update = $matches[0];
    }
    $for_update or die "didn't find update for ".
        join "\n", map { "$_: ".$old_event->$_ } qw/startday type loc leader band comments /;

    next if $for_update->event_id == 543;

    $update{$for_update->event_id} = $old_event->comments;

    if (!$dry_run) {
        $for_update->short_desc(join '', $for_update->short_desc ,' ', '<em>', $old_event->comments, '</em>');
        $for_update->update();
    }
}

if ($dry_run) {
    say dump %update;
}
 
say "done";
