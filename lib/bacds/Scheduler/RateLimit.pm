=head1 NAME

bacds::Scheduler::RateLimit - count recent events and say when there are too many

=head1 SYNOPSIS

    use bacds::Scheduler::RateLimit;
    my $c = 'bacds::Scheduler::RateLimit';

    # record a request and refuse it if there have been too many
    if ($c->hit(member_link_ip => request->address)) {
        ...refuse...
    }

    # or check and record separately, e.g. to count only failures
    if ($c->over_limit(signin_fail_email => $email)) { ...refuse... }
    ...
    $c->record(signin_fail_email => $email) if $login_failed;

=head1 DESCRIPTION

Each counted event is a row in the rate_limit_events table, with a bucket
name (what's being limited) and a key (who: an IP address, an email, a
CiviCRM contact id). A bucket is over its limit once it has C<max> rows for
that key in the last C<window> seconds.

The counts are in the database rather than in memory because Apache runs
the app in several processes, and they all need to see the same counts.
There's no proxy in front of Apache, so request->address is the client's
real IP.

If the database call fails (say the table hasn't been created yet), this
warns and lets the request through: a broken rate limiter shouldn't stop
everyone from logging in.

Rows older than a day are deleted at most once an hour per process.

=head1 LIMITS

%Limits holds the default C<max> and C<window> for each bucket. They can be
overridden with the C<rate_limits> setting in config.yml (see
bacds::Scheduler), e.g.

    rate_limits:
      signin_fail_email: { max: 5, window: 900 }

=cut

package bacds::Scheduler::RateLimit;

use 5.32.1;
use warnings;

use DateTime;

use bacds::Scheduler::Util::Db qw/get_dbh/;

our %Limits = (
    # failed /bacds-signin attempts for one email address
    signin_fail_email   => { max => 5,  window => 15 * 60 },
    # failed /bacds-signin attempts from one IP address
    signin_fail_ip      => { max => 20, window => 60 * 60 },
    # member portal magic-link requests from one IP address
    member_link_ip      => { max => 10, window => 60 * 60 },
    # magic-link emails sent to one CiviCRM contact
    member_link_contact => { max => 3,  window => 60 * 60 },
);

use constant PRUNE_AFTER => 24 * 60 * 60;
use constant PRUNE_EVERY => 60 * 60;

=head2 over_limit($bucket, $key)

True if $key already has the bucket's max events in its window.

=cut

sub over_limit {
    my ($class, $bucket, $key) = @_;

    my $limit = _limit_for($bucket);

    my $count = eval {
        my $dbh = get_dbh();
        my $since = DateTime->now->subtract(seconds => $limit->{window});
        $dbh->resultset('RateLimitEvent')->search({
            bucket     => $bucket,
            event_key  => _normalize($key),
            created_ts => { '>' => $dbh->storage->datetime_parser->format_datetime($since) },
        })->count;
    };
    if (!defined $count) {
        warn "RateLimit->over_limit($bucket) failed, allowing the request: $@";
        return 0;
    }

    return $count >= $limit->{max};
}

=head2 record($bucket, $key)

Counts one event for $key in the bucket.

=cut

sub record {
    my ($class, $bucket, $key) = @_;

    _limit_for($bucket); # dies on a typo in the bucket name

    eval {
        get_dbh()->resultset('RateLimitEvent')->create({
            bucket     => $bucket,
            event_key  => _normalize($key),
            created_ts => DateTime->now,
        });
        1;
    } or warn "RateLimit->record($bucket) failed: $@";

    $class->_maybe_prune;
    return;
}

=head2 hit($bucket, $key)

If $key is over the bucket's limit, returns true. Otherwise records an event
and returns false. Refused requests aren't recorded, so a client that keeps
trying is let back in once the window has passed.

=cut

sub hit {
    my ($class, $bucket, $key) = @_;

    return 1 if $class->over_limit($bucket, $key);
    $class->record($bucket, $key);
    return 0;
}

=head2 prune

Deletes events older than a day. Called automatically from record().

=cut

sub prune {
    my ($class) = @_;

    eval {
        my $dbh = get_dbh();
        my $before = DateTime->now->subtract(seconds => PRUNE_AFTER);
        $dbh->resultset('RateLimitEvent')->search({
            created_ts => { '<' => $dbh->storage->datetime_parser->format_datetime($before) },
        })->delete;
        1;
    } or warn "RateLimit->prune failed: $@";
}

sub _maybe_prune {
    my ($class) = @_;

    state $last_pruned = 0;
    return if time - $last_pruned < PRUNE_EVERY;
    $last_pruned = time;

    $class->prune;
}

sub _limit_for {
    my ($bucket) = @_;
    return $Limits{$bucket} || die "unknown rate limit bucket '$bucket'\n";
}

sub _normalize {
    my ($key) = @_;
    $key //= '';
    $key =~ s/^\s+|\s+$//g;
    return lc substr $key, 0, 255;
}

1;
