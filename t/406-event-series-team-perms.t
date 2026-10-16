# Tests that a programmer who can edit or create an event can't attach it to
# a series or team they aren't linked to (check_series_and_teams in
# bacds::Scheduler::Plugin::Auth)

use 5.32.1;
use warnings;
use utf8;

use Data::Dump qw/dump/;
use HTTP::Request::Common qw/PUT POST/;
use JSON::MaybeXS qw/decode_json/;
use Test::More tests => 39;

use bacds::Scheduler;
use bacds::Scheduler::Util::Db qw/get_dbh/;
use bacds::Scheduler::Util::Test qw/setup_test_db get_tester/;

setup_test_db;
my $dbh = get_dbh();

#
# fixture: series A and B, teams T1 and T2, and an event in series A with
# team T1
#
sub make_programmer {
    my ($email) = @_;
    return $dbh->resultset('Programmer')->create({
        name => $email, email => $email, is_superuser => 0, is_deleted => 0,
    });
}
my $series_a = $dbh->resultset('Series')->create({ name => 'Series A', series_xid => 'SERIES-A', is_deleted => 0 });
my $series_b = $dbh->resultset('Series')->create({ name => 'Series B', series_xid => 'SERIES-B', is_deleted => 0 });
my $team_1   = $dbh->resultset('Team')->create({ name => 'Team One', team_xid => 'TEAM-1', is_deleted => 0 });
my $team_2   = $dbh->resultset('Team')->create({ name => 'Team Two', team_xid => 'TEAM-2', is_deleted => 0 });

my $event = $dbh->resultset('Event')->create({
    name => 'the event', synthetic_name => 'the event',
    start_date => '2022-05-01', series_id => $series_a->series_id,
    uuid => 'event-move-perms-test', is_deleted => 0,
});
$event->add_to_teams($team_1, { ordering => 1 });
my $event_id = $event->event_id;

# linked to series A only
my $series_prog = make_programmer('series-a@example.com');
$series_prog->add_to_series($series_a, { ordering => 1 });

# linked to series A and series B
my $two_series_prog = make_programmer('series-a-and-b@example.com');
$two_series_prog->add_to_series($series_a, { ordering => 1 });
$two_series_prog->add_to_series($series_b, { ordering => 2 });

# linked to team T1 only
my $team_prog = make_programmer('team-1@example.com');
$team_prog->add_to_teams($team_1, { ordering => 1 });

# linked to series A and team T1
my $series_team_prog = make_programmer('series-a-team-1@example.com');
$series_team_prog->add_to_series($series_a, { ordering => 1 });
$series_team_prog->add_to_teams($team_1, { ordering => 1 });

my %tester = map { $_ => get_tester(auth => 1, user_email => $_) }
    qw(series-a@example.com series-a-and-b@example.com team-1@example.com
       series-a-team-1@example.com);
$tester{admin} = get_tester(auth => 1); # petertheadmin, a superuser

# Sends a PUT like the scheduler's form does, with series_id and every
# team_id. Pass series_id => undef to leave series_id out.
sub put_event {
    my ($who, %args) = @_;
    my @content = (event_id => $event_id, name => $args{name} // 'the event');
    push @content, series_id => $args{series_id} if exists $args{series_id} && defined $args{series_id};
    push @content, team_id => $_ for @{ $args{team_ids} // [''] };
    return $tester{$who}->request(PUT "/event/$event_id", Content => \@content);
}

sub error_num {
    my ($res) = @_;
    my $data = eval { decode_json($res->content) } or return 'not JSON: '.$res->content;
    return $data->{errors}[0]{num};
}

sub reset_event {
    $event->discard_changes;
    $event->update({ series_id => $series_a->series_id, name => 'the event' });
    $event->set_teams([$team_1], { ordering => 1 });
}

sub event_teams { join ',', sort map $_->name, $event->teams }

my $A  = $series_a->series_id;
my $B  = $series_b->series_id;
my $T1 = $team_1->team_id;
my $T2 = $team_2->team_id;
my $res;

#
# a series programmer
#
reset_event();
$res = put_event('series-a@example.com', name => 'renamed', series_id => $A, team_ids => [$T1]);
is $res->code, 200, "series programmer: an ordinary edit that doesn't change series or teams works"
    or diag $res->content;
$event->discard_changes;
is $event->name, 'renamed', '...and saved';

reset_event();
$res = put_event('series-a@example.com', series_id => $B, team_ids => [$T1]);
is $res->code, 403, "series programmer: can't move the event into a series they're not linked to";
is error_num($res), 40305, '...error 40305';
$event->discard_changes;
is $event->series_id, $A, '...and the series is unchanged';

$res = put_event('series-a@example.com', series_id => '', team_ids => [$T1]);
is $res->code, 403, "series programmer: can't take the event out of its series";
is error_num($res), 40304, '...error 40304';

$res = put_event('series-a@example.com', series_id => 'NULL', team_ids => [$T1]);
is $res->code, 403, '...including with series_id=NULL';

$res = put_event('series-a@example.com', series_id => $A, team_ids => [$T1, $T2]);
is $res->code, 403, "series programmer: can't add a team they're not linked to";
is error_num($res), 40306, '...error 40306';
like decode_json($res->content)->{errors}[0]{msg}, qr{not linked to: Team Two$},
    '...naming the team';
is event_teams(), 'Team One', '...and the teams are unchanged';

$res = put_event('series-a@example.com', series_id => $A, team_ids => ['']);
is $res->code, 200, 'series programmer: can remove a team, even one they are not linked to';
is event_teams(), '', '...and the team is gone';

reset_event();
$res = put_event('series-a@example.com', name => 'no series_id', team_ids => [$T1]);
is $res->code, 200, 'series programmer: a PUT without series_id is fine';
$event->discard_changes;
is $event->series_id, $A, '...and leaves the series alone';

#
# a programmer linked to both series can move the event between them
#
reset_event();
$res = put_event('series-a-and-b@example.com', series_id => $B, team_ids => [$T1]);
is $res->code, 200, 'programmer linked to both series: can move the event from A to B'
    or diag $res->content;
$event->discard_changes;
is $event->series_id, $B, '...and it moved';

#
# a team programmer
#
reset_event();
$res = put_event('team-1@example.com', name => 'team edit', series_id => $A, team_ids => [$T1]);
is $res->code, 200, "team programmer: an ordinary edit works (they're linked to the event's team)"
    or diag $res->content;

$res = put_event('team-1@example.com', series_id => '', team_ids => [$T1]);
is $res->code, 403, "team programmer: can't take the event out of its series";
is error_num($res), 40304, '...error 40304';

$res = put_event('team-1@example.com', series_id => $B, team_ids => [$T1]);
is $res->code, 403, "team programmer: can't move it into a series they're not linked to";

$res = put_event('team-1@example.com', series_id => $A, team_ids => [$T1, $T2]);
is $res->code, 403, "team programmer: can't add another team";

#
# a series programmer who's also linked to a team can add that team
#
reset_event();
$event->set_teams([], {});
$res = put_event('series-a-team-1@example.com', series_id => $A, team_ids => [$T1]);
is $res->code, 200, 'series+team programmer: can add a team they are linked to'
    or diag $res->content;
is event_teams(), 'Team One', '...and it was added';

$res = put_event('series-a-team-1@example.com', series_id => $A, team_ids => [$T1, $T2]);
is $res->code, 403, "series+team programmer: still can't add a team they're not linked to";

#
# a superuser can do anything
#
reset_event();
$res = put_event('admin', series_id => $B, team_ids => [$T1, $T2]);
is $res->code, 200, 'superuser: can move the event and add any team' or diag $res->content;
$event->discard_changes;
is $event->series_id, $B, '...moved';
is event_teams(), 'Team One,Team Two', '...teams added';

$res = put_event('admin', series_id => '', team_ids => ['']);
is $res->code, 200, 'superuser: can take the event out of its series';
$event->discard_changes;
ok !$event->series_id, '...and it has no series';

#
# creating an event
#
sub post_event {
    my ($who, %args) = @_;
    my @content = (
        name => 'new event', synthetic_name => 'new event', start_date => '2022-06-01',
        is_canceled => 0, and_friends => 0, force_canon_ical => 0, is_series_defaults => 0,
        series_id => $args{series_id},
    );
    push @content, team_id => $_ for @{ $args{team_ids} // [''] };
    return $tester{$who}->request(POST '/event/', Content => \@content);
}

my $events_before = $dbh->resultset('Event')->count;

$res = post_event('series-a@example.com', series_id => $A, team_ids => ['']);
is $res->code, 200, 'creating: series programmer can create an event in their series'
    or diag $res->content;

$res = post_event('series-a@example.com', series_id => $A, team_ids => [$T2]);
is $res->code, 403, "creating: series programmer can't create it with a team they're not linked to";
is error_num($res), 40306, '...error 40306';

$res = post_event('series-a-team-1@example.com', series_id => $A, team_ids => [$T1]);
is $res->code, 200, 'creating: series+team programmer can create it with their team'
    or diag $res->content;

$res = post_event('series-a@example.com', series_id => $B, team_ids => ['']);
is $res->code, 403, "creating: still can't create in a series they're not linked to";
is error_num($res), 40303, '...error 40303 as before';

$res = post_event('admin', series_id => $B, team_ids => [$T2]);
is $res->code, 200, 'creating: superuser can create anything';

is $dbh->resultset('Event')->count, $events_before + 3, 'only the allowed events were created';
