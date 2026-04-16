package bacds::Scheduler::Schema::Role::EventCalendarLinks;

use 5.32.1;
use warnings;

use Role::Tiny;

use feature 'signatures';
no warnings 'experimental::signatures';

use bacds::Scheduler::ICal;

sub gcal_link ($event) {
    return bacds::Scheduler::ICal->event_to_gcal_link($event);
}

sub ical_link ($event) {
    return bacds::Scheduler::ICal->event_to_ical_link($event);
}

1;
