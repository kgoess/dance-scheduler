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
use Test::More tests => 5;

use bacds::Scheduler;
use bacds::Scheduler::Schema;
use bacds::Scheduler::Util::Time qw/get_now/;
use bacds::Scheduler::Util::Db qw/get_dbh/;

use bacds::Scheduler::Util::Test qw/setup_test_db get_tester/;
setup_test_db;

my $app = bacds::Scheduler->to_app;
my $test = get_tester(auth => 1);
my $dbh = get_dbh();

my $ParentOrg;
my $ParentOrg_Id;
my $Created_Time;
my $Modified_Time;


subtest 'Invalid GET /parent_org/1' => sub{
    plan tests=>2;

    my ($res, $decoded, $got, $expected);
    $res = $test->request( GET '/parent_org/1' );
    ok($res->is_success, 'returned success');

    $decoded = decode_json($res->content);
    $expected = {
        data => '',
        errors => [{
            msg => 'Nothing found for parent_org_id 1',
            num => 3201,
        }]
    };
    eq_or_diff $decoded, $expected, 'error msg matches';
};

subtest 'POST /parent_org' => sub{
    plan tests=>2;

    my ($expected, $res, $decoded, $got);
    my $new_parent_org = {
        full_name        => "test parent_org",
        abbreviation        => "TPO",
        parent_org_id   => '', # the webapp sends full_name=test+parent_org&parent_org_id=
    };
    $ENV{TEST_NOW} = 1651112285;
    $Created_Time = get_now()->iso8601;
    $res = $test->request(POST '/parent_org/', $new_parent_org );
    ok($res->is_success, 'returned success');

    $decoded = decode_json($res->content);
    $got = $decoded->{data};
    $expected = {
        parent_org_id    => 1,
        full_name        => $new_parent_org->{full_name},
        abbreviation     => $new_parent_org->{abbreviation},
        created_ts  => $Created_Time,
        modified_ts => $Created_Time,
        is_deleted  => 0,
    };
    eq_or_diff $got, $expected, 'return matches';

    # now save it for the subsequent tests
    $ParentOrg = $dbh->resultset('ParentOrg')->find($decoded->{data}{parent_org_id});
    $ParentOrg_Id = $ParentOrg->parent_org_id;
};


subtest 'GET /parent_org/#' => sub{
    plan tests=>2;

    my ($res, $decoded, $got, $expected);

    $res  = $test->request( GET "/parent_org/$ParentOrg_Id" );
    ok( $res->is_success, 'returned success' );

    $decoded = decode_json($res->content); 
    $got = $decoded->{data};
    $expected = {
        parent_org_id    => $ParentOrg_Id,
        full_name        => $ParentOrg->full_name,
        abbreviation     => $ParentOrg->abbreviation,
        created_ts  => $Created_Time,
        modified_ts => $Created_Time,
        is_deleted  => 0,
    };
    eq_or_diff $got, $expected, 'return matches';
};


subtest 'PUT /parent_org/#' => sub {
    plan tests => 5;

    my ($res, $decoded, $got, $expected);
    my $edit_parent_org = {
        full_name        => "new name",
        abbreviation     => "NNO",
    };
    $ENV{TEST_NOW} += 100;
    $Modified_Time = get_now()->iso8601;
    $res = $test->request( PUT "/parent_org/$ParentOrg_Id" , content => $edit_parent_org);
    ok( $res->is_success, 'returned success' );
    
    $decoded = decode_json($res->content);
    $got = $decoded->{data};
    $expected = {
        parent_org_id    => $ParentOrg_Id,
        full_name        => $edit_parent_org->{full_name},
        abbreviation     => $edit_parent_org->{abbreviation},
        created_ts  => $Created_Time,
        modified_ts => $Modified_Time,
        is_deleted  => 0,
    };
    eq_or_diff $got, $expected, 'return matches';

    $res  = $test->request( GET "/parent_org/$ParentOrg_Id" );
    $decoded = decode_json($res->content); 
    $got = $decoded->{data};
    eq_or_diff $got, $expected, 'GET changed after PUT';

    # update our global parent_org object
    $ParentOrg = $dbh->resultset('ParentOrg')->find($ParentOrg_Id);


    # demonstrate behavior on PUT with a non-existent pkey
    $test->put_ok('/parent_org/45789', { content => $edit_parent_org })
        or die $test->res->content;
    $decoded = decode_json($test->res->content);
    is $decoded->{errors}[0]{msg}, "Update failed for PUT /parent_org: parent_org_id '45789' not found",
        'failed PUT has expected error msg' or diag explain $decoded;
};


subtest 'GET /parent_orgAll' => sub{
    plan tests => 2;

    my ($res, $decoded, $got, $expected);
    $res  = $test->request( GET '/parent_orgAll' );
    ok( $res->is_success, 'Returned success' );

    $decoded = decode_json($res->content);
    $got = $decoded->{data};
    $expected = [
      {
        parent_org_id    => $ParentOrg_Id,
        full_name        => $ParentOrg->full_name,
        abbreviation     => $ParentOrg->abbreviation,
        created_ts  => $Created_Time,
        modified_ts => $Modified_Time,
        is_deleted  => 0,
      },
    ];
    eq_or_diff $got, $expected, 'matches';
};
