package bacds::Scheduler::Schema::Role::SeriesCalendarLinks;

use 5.32.1;
use warnings;

use Role::Tiny;

use feature 'signatures';
no warnings 'experimental::signatures';

use bacds::Scheduler::ICal;

sub ical_link ($series) {
    return bacds::Scheduler::ICal->series_to_ical_link($series);
}

1;
