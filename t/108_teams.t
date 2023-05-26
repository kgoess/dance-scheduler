use 5.16.0;
use warnings;

use Data::Dump qw/dump/;
use DateTime::Format::Strptime qw/strptime/;
use DateTime;
use HTTP::Request::Common;
use JSON::MaybeXS qw/decode_json/;
use Plack::Test;
use Ref::Util qw/is_coderef/;
use Test::Differences qw/eq_or_diff/;
use Test::More tests => 6;
use Test::Warn;

use bacds::Scheduler;
use bacds::Scheduler::Schema;
use bacds::Scheduler::Util::Time qw/get_now/;
use bacds::Scheduler::Util::Db qw/get_dbh/;

use bacds::Scheduler::Util::Test qw/setup_test_db get_tester/;
setup_test_db;

my $app = bacds::Scheduler->to_app;
my $test = get_tester(auth => 1);
my $dbh = get_dbh();

my $Team;
my $Team_Id;
my $Created_Time;
my $Modified_Time;


subtest 'Invalid GET /team/1' => sub {
    plan tests => 2;

    my ($res, $decoded, $got, $expected);
    $res = $test->request( GET '/team/1' );
    ok($res->is_success, 'returned success');

    $decoded = decode_json($res->content);
    $expected = {
        data => '',
        errors => [{
            msg => 'Nothing found for Team: primary key "1"',
            num => 404,
        }]
    };
    eq_or_diff $decoded, $expected, 'error msg matches';
};

subtest 'POST /team' => sub {
    plan tests => 2;

    my ($expected, $res, $decoded, $got);
    my $new_team = {
        name        => 'test team',
        team_xid    => 'TESTMORRIS',
        contact     => 'alice morris',
        description => 'blah blah',
        team_url    => 'https://team_url.com',
        photo_url   => 'https://photo_url.com',
        team_id     => '', # the webapp sends name=test+team&team_id=
    };
    $ENV{TEST_NOW} = 1651112285;
    $Created_Time = get_now()->iso8601;
    $res = $test->request(POST '/team/', $new_team );
    ok($res->is_success, 'returned success');

    $decoded = decode_json($res->content);
    $got = $decoded->{data};
    $expected = {
        team_id    => 1,
        contact    => 'alice morris',
        description => 'blah blah',
        name  => 'test team',
        photo_url => 'https://photo_url.com',
        sidebar => undef,
        styles => [],
        parent_orgs => [],
        team_url => 'https://team_url.com',
        team_xid => 'TESTMORRIS',
        created_ts  => $Created_Time,
        modified_ts => $Created_Time,
        is_deleted  => 0,
    };
    eq_or_diff $got, $expected, 'return matches';

    # now save it for the subsequent tests
    $Team = $dbh->resultset('Team')->find($decoded->{data}{team_id});
    $Team_Id = $Team->team_id;
};

subtest 'POST /team duplicate' => sub {
    plan tests => 3;

    my ($expected, $res, $decoded, $got);
    my $dup_team = {
        name => 'test team',
        team_xid => 'TESTMORRIS_2',
    };
    local $ENV{TEST_DUP_VALUE} = 'test team';
    warning_is {
        $res = $test->request(POST '/team/', $dup_team );
    } 'UNIQUE constraint failed: teams.name: test team';

    ok($res->is_success, 'still a 200-OK though');

    $got = decode_json($res->content);
    $expected = {
        data   => "",
        errors => [ {
            msg => "There is already an entry for 'test team' under Team",
            num => 409,
          },
        ],
    };
    eq_or_diff $got, $expected, 'return matches';
};

subtest 'GET /team/#' => sub {
    plan tests => 2;

    my ($res, $decoded, $got, $expected);

    $res  = $test->request( GET "/team/$Team_Id" );
    ok( $res->is_success, 'returned success' );

    $decoded = decode_json($res->content); 
    $got = $decoded->{data};
    $expected = {
        contact => $Team->contact,
        description => $Team->description,
        is_deleted => 0,
        name => $Team->name,
        photo_url => $Team->photo_url,
        sidebar => $Team->sidebar,
        parent_orgs => [],
        styles => [],
        team_id => $Team_Id,
        team_url => $Team->team_url,
        team_xid => $Team->team_xid,
        created_ts => $Created_Time,
        modified_ts => $Created_Time,
    };
    eq_or_diff $got, $expected, 'return matches';
};


subtest 'PUT /team/#' => sub {
    plan tests => 5;

    my ($res, $decoded, $got, $expected);
    my $edit_team = {
        name => 'new name',
        team_xid => 'NNO',
    };
    $ENV{TEST_NOW} += 100;
    $Modified_Time = get_now()->iso8601;
    $res = $test->request( PUT "/team/$Team_Id" , content => $edit_team);
    ok( $res->is_success, 'returned success' );
    
    $decoded = decode_json($res->content);
    $got = $decoded->{data};
    $expected = {
        contact => $Team->contact,
        description => $Team->description,
        is_deleted => 0,
        name => 'new name',
        photo_url => $Team->photo_url,
        sidebar => $Team->sidebar,
        parent_orgs => [],
        styles => [],
        team_id => $Team->id,
        team_url => $Team->team_url,
        team_xid => 'NNO',
        created_ts => $Created_Time,
        modified_ts => $Modified_Time,
    };
    eq_or_diff $got, $expected, 'return matches';

    $res  = $test->request( GET "/team/$Team_Id" );
    $decoded = decode_json($res->content); 
    $got = $decoded->{data};
    eq_or_diff $got, $expected, 'GET changed after PUT';

    # update our global team object
    $Team = $dbh->resultset('Team')->find($Team_Id);


    # demonstrate behavior on PUT with a non-existent pkey
    $test->put_ok('/team/45789', { content => $edit_team })
        or die $test->res->content;
    $decoded = decode_json($test->res->content);
    is $decoded->{errors}[0]{msg}, 'Nothing found for Team: primary key "45789"',
        'failed PUT has expected error msg' or diag explain $decoded;
};


subtest 'GET /teamAll' => sub{
    plan tests => 2;

    my ($res, $decoded, $got, $expected);
    $res  = $test->request( GET '/teamAll' );
    ok( $res->is_success, 'Returned success' );

    $decoded = decode_json($res->content);
    $got = $decoded->{data};
    $expected = [
      {
        contact => $Team->contact,
        description => $Team->description,
        is_deleted => 0,
        name => $Team->name,
        photo_url => $Team->photo_url,
        sidebar => $Team->sidebar,
        # not included in *All styles => [],
        # not included in *All parent_orgs => [],
        team_id => $Team->id,
        team_url => $Team->team_url,
        team_xid => $Team->team_xid,
        created_ts => $Created_Time,
        modified_ts => $Modified_Time,
      },
    ];
    eq_or_diff $got, $expected, 'matches';
};
