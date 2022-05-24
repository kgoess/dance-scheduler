package bacds::Scheduler::Schema::Role::AutoTimestamps;
use 5.16.0;
use warnings;
use Role::Tiny;
use bacds::Scheduler::Util::Time qw/get_now/;

before insert => sub {
#Set created_ts, modified_ts to now
    my $self = shift;

    my $time = get_now();
    foreach my $column (qw/
        created_ts
        modified_ts
        /){
        $self->store_column($column, $time);
    }
};

before update => sub {
#Set modified_ts to now
    my $self = shift;

    my $time = get_now();
    $self->modified_ts($time);
};

1;
