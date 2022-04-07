#!/usr/bin/perl

# just an example of how the DBIx::Class API works

use 5.16.0;
use warnings;

die "if you really want to run this, edit the script to disable this line";

use bacds::Scheduler::Schema;
use bacds::Scheduler;

my $dbh = bacds::Scheduler -> get_dbh();

my $new_event = $dbh->resultset('Event')->new({
    name => 'Second Test Event',
    start_time => '2022-01-05T12:34',
    end_time => '2022-01-05T14:34',
    is_camp => 0,
    long_desc => q{This is the long event / wordy description for the second
        event, which is overly long orem ipsum dolor sit amet, consectetur adipiscing
        elit. Proin vitae ligula vitae elit cursus rhoncus. Integer vitae malesuada
        tellus, nec lacinia est. Suspendisse potenti. Mauris nunc sem, porta quis
        hendrerit eget, ullamcorper ut felis. Mauris augue odio, rutrum eget urna id,
        finibus bibendum mauris. Mauris gravida dapibus commodo. Pellentesque eget
        cursus erat. Cras finibus tellus accumsan, fermentum orci ac, venenatis velit.
        Nullam in sodales ex. Nulla in purus velit. Vivamus hendrerit auctor accumsan.
        Donec ultricies diam nec ornare malesuada. In sollicitudin sodales dictum. Nam
        enim quam, tincidunt sit amet},
    short_desc => 'Short desc',
    event_type => 'ONEDAY',
 });
$new_event->insert; # Auto-increment primary key filled in after INSERT

