=head1 NAME

bacds::Scheduler::Auditor - logs actions to audit_log table

=head1 SYNOPSIS

    $auditor = bacds::Scheduler::Auditor->new(
        programmer_id => 123,
        target => 'Venue',
        target_id => 456,
        action => 'change',
    );

    $auditor->add_update_message(hall_name => "Bob's Big Boy");
    $auditor->add_update_message(city => "Gotham");

    $auditor->save;

    prgr  target      target_id   action      message
    ----- ----------  ----------  ---------- -------------------------------------
    123   Event       456         update      hall_name to "Bob's Big Boy", city to "Gotham"

=head1 DESCRIPTION

This simplistically tracks changes to the model from the web UI in the
audit_log table, so we have some chance of figuring out changes if we're ever
asked.

"var auditor" is set up in the "hook before" in bacds::Scheduler. The
individual routes are in charge of passing the auditor to put_row and post_row,
and calling $auditor->save if the thing was successful.

=cut

package bacds::Scheduler::Auditor;

use 5.16.0;
use warnings;

use Carp qw/croak/;
use Data::Dump qw/dump/;
use Moo;

use bacds::Scheduler::Util::Db qw/get_dbh/;

has programmer_id => (
    is => 'ro',
);

# this is the "model name" and its pk, could be other things someday too
has [qw/target target_id/] => (
    is => 'rw',
);

has action => (
    is => 'rw',
);

# e.g. name to "saturday night danceoff", start_date to "2022-05-01",
has message => (
    is => 'rw',
    default => sub { '' },
    trigger => sub { $_[0]->is_dirty(1) },
);

has is_dirty => (
    is => 'rw',
);


# convert
#     ->new(programmer => $programmer)
# to  ->new(programmer_id => $programmer_id)
# and ->new(http_method => 'PUT')
# to  ->new(action => 'change')
around BUILDARGS => sub {
    my ($orig_method, $class, @args) = @_;

    my %args;
    if (@args == 1 && ref $args[0]) {
        %args = %{ $args[0] };
    } else {
        %args = @args;
    }

    if (my $programmer = delete $args{programmer}) {
        $args{programmer_id} = $programmer->programmer_id;
    }
    if (my $http_method = delete $args{http_method}) {
        given ($http_method) {
            when ('POST') {
                $args{action} = 'create';
            }
            when ('PUT') {
                $args{action} = 'update';
            }
            default {
                $args{action} = "http: $http_method";
            }
        }
    }

    return $class->$orig_method(%args);
};


sub add_update_message {
    my ($self, $key, $value) = @_;

    $value =~ s/T00:00:00$//; # e.g. start_day

    $self->is_dirty(1);

    my $max_len = 60;
    substr($value, $max_len) = '...' if length $value > $max_len;

    my $update = qq{$key to "$value"};
    my $message = $self->message;

    my $max = 2048; # from the db, utf8 might be problematic?

    if (length($message) > $max) {
        substr($message, $max) = '...';
    } elsif ($message) {
        $message .= ", $update";
    } else {
        $message = $update;
    }

    $self->message($message);
}

sub save {
    my ($self) = @_;

    return unless $self->is_dirty;

    my $dbh = get_dbh();

    my $auditlog = $dbh->resultset('AuditLog')->new({
        programmer_id => $self->programmer_id,
        target => $self->target,
        target_id => $self->target_id,
        action => $self->action,
        message => $self->message,
    });
    $auditlog->insert;
}

1;
