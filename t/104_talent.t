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

my $Talent;
my $Talent_Id;
my $Created_Time;
my $Modified_Time;


subtest 'Invalid GET /talent/1' => sub{
    plan tests=>2;

    my ($res, $decoded, $got, $expected);
    $res = $test->request( GET '/talent/1' );
    ok($res->is_success, 'returned success');

    $decoded = decode_json($res->content);
    $expected = {
        data => '',
        errors => [{
            msg => 'Nothing found for Talent: primary key "1"',
            num => 404,
        }]
    };
    eq_or_diff $decoded, $expected, 'error msg matches';
};

subtest 'POST /talent' => sub {
    plan tests=>2;

    my ($expected, $res, $decoded, $got);
    my $new_talent = {
        talent_id   => '', # this should be ignored by the model
        name        => "test talent",
        url         => 'http://url',
        photo_url   => 'http://photo-url',
    };
    $ENV{TEST_NOW} = 1651112285;
    $Created_Time = get_now()->iso8601;
    $res = $test->request(POST '/talent/', $new_talent );
    ok($res->is_success, 'returned success');

    $decoded = decode_json($res->content);
    $got = $decoded->{data};
    $expected = {
        talent_id     => 1,
        name        => $new_talent->{name},
        url         => $new_talent->{url},
        photo_url   => $new_talent->{photo_url},
        created_ts  => $Created_Time,
        modified_ts => $Created_Time,
        is_deleted  => 0,
    };
    eq_or_diff $got, $expected, 'return matches';

    # now save it for the subsequent tests
    $Talent = $dbh->resultset('Talent')->find($decoded->{data}{talent_id});
    $Talent_Id = $Talent->talent_id;
};

subtest 'POST /talent duplicate' => sub {
    plan tests => 3;

    my ($expected, $res, $decoded, $got);
    my $dup_talent = {
        name        => "test talent",
    };
    local $ENV{TEST_DUP_VALUE} = 'test talent';
    warning_is {
        $res = $test->request(POST '/talent/', $dup_talent );
    } 'UNIQUE constraint failed: talent.name: test talent';

    ok($res->is_success, 'still a 200-OK though');

    $got = decode_json($res->content);
    $expected = {
        data   => "",
        errors => [ {
            msg => "There is already an entry for 'test talent' under Talent",
            num => 409,
          },
        ],
    };
    eq_or_diff $got, $expected, 'return matches';
};


subtest 'GET /talent/#' => sub {
    plan tests=>2;

    my ($res, $decoded, $got, $expected);

    $res  = $test->request( GET "/talent/$Talent_Id" );
    ok( $res->is_success, 'returned success' );

    $decoded = decode_json($res->content); 
    $got = $decoded->{data};
    $expected = {
        talent_id   => $Talent_Id,
        name        => $Talent->name,
        url         => $Talent->url,
        photo_url   => $Talent->photo_url,
        created_ts  => $Created_Time,
        modified_ts => $Created_Time,
        is_deleted  => 0,
    };
    eq_or_diff $got, $expected, 'return matches';
};


subtest 'PUT /talent/#' => sub {
    plan tests => 5;

    my ($res, $decoded, $got, $expected);
    my $edit_talent = {
        name        => "new name",
        url         => "http://new-url",
        photo_url   => $Talent->photo_url,
    };
    $ENV{TEST_NOW} += 100;
    $Modified_Time = get_now()->iso8601;
    $res = $test->request( PUT "/talent/$Talent_Id" , content => $edit_talent);
    ok( $res->is_success, 'returned success' );
    
    $decoded = decode_json($res->content);
    $got = $decoded->{data};
    $expected = {
        talent_id   => $Talent_Id,
        name        => $edit_talent->{name},
        url         => $edit_talent->{url},
        photo_url   => $edit_talent->{photo_url},
        created_ts  => $Created_Time,
        modified_ts => $Modified_Time,
        is_deleted  => 0,
    };
    eq_or_diff $got, $expected, 'return matches';

    $res  = $test->request( GET "/talent/$Talent_Id" );
    $decoded = decode_json($res->content); 
    $got = $decoded->{data};
    eq_or_diff $got, $expected, 'GET changed after PUT';

    # update our global talent object
    $Talent = $dbh->resultset('Talent')->find($Talent_Id);


    # demonstrate behavior on PUT with a non-existent pkey
    $test->put_ok('/talent/45789', { content => $edit_talent })
        or die $test->res->content;
    $decoded = decode_json($test->res->content);
    is $decoded->{errors}[0]{msg}, 'Nothing found for Talent: primary key "45789"',
        'failed PUT has expected error msg' or diag explain $decoded;
};


subtest 'GET /talentAll' => sub {
    plan tests => 2;

    my ($res, $decoded, $got, $expected);
    $res  = $test->request( GET '/talentAll' );
    ok( $res->is_success, 'Returned success' );

    $decoded = decode_json($res->content);
    $got = $decoded->{data};
    $expected = [
      {
        talent_id   => $Talent_Id,
        name        => $Talent->name,
        url         => $Talent->url,
        photo_url   => $Talent->photo_url,
        created_ts  => $Created_Time,
        modified_ts => $Modified_Time,
        is_deleted  => 0,
      },
    ];
    eq_or_diff $got, $expected, 'matches';
};
