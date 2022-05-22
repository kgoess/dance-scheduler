package bacds::Scheduler::Schema::Role::AutoTimestamps;
use 5.16.0;
use warnings;
use Role::Tiny;
use bacds::Scheduler::Util::Time qw/get_now/;

around insert => sub {
#Set created_ts, modified_ts to now
    my $orig = shift;
    my $self = shift;

    my $time = get_now();
    foreach my $column (qw/
        created_ts
        modified_ts
        /){
        $self->store_column($column, $time);
    }
    return $orig->($self, @_);
};

around update => sub {
#Set modified_ts to now
    my $orig = shift;
    my $self = shift;

    my $time = get_now();
    $self->modified_ts($time);

    return $orig->($self, @_);
};

1;
