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

my $Band;
my $Band_Id;
my $Created_Time;
my $Modified_Time;


subtest 'Invalid GET /band/1' => sub {
    plan tests=>2;

    my ($res, $decoded, $got, $expected);
    $res = $test->request( GET '/band/1' );
    ok($res->is_success, 'returned success');

    $decoded = decode_json($res->content);
    $expected = {
        data => '',
        errors => [{
            msg => 'Nothing found for Band: primary key "1"',
            num => 404,
        }]
    };
    eq_or_diff $decoded, $expected, 'error msg matches';
};

subtest 'POST /band' => sub {
    plan tests=>2;

    my ($expected, $res, $decoded, $got);
    my $new_band = {
        band_id     => '', #This should be ignored by the model
        name        => "test band",
        url         => 'http://url',
        photo_url   => 'http://photo-url',
    };
    $ENV{TEST_NOW} = 1651112285;
    $Created_Time = get_now()->iso8601;
    $res = $test->request(POST '/band/', $new_band );
    ok($res->is_success, 'returned success');

    $decoded = decode_json($res->content);
    $got = $decoded->{data};
    $expected = {
        band_id     => 1,
        name        => $new_band->{name},
        url         => $new_band->{url},
        photo_url   => $new_band->{photo_url},
        created_ts  => $Created_Time,
        modified_ts => $Created_Time,
        is_deleted  => 0,
        talents     => [],
    };
    eq_or_diff $got, $expected, 'return matches';

    # now save it for the subsequent tests
    $Band = $dbh->resultset('Band')->find($decoded->{data}{band_id});
    $Band_Id = $Band->band_id;
};

subtest 'POST /band duplicate' => sub {
    plan tests => 3;

    my ($expected, $res, $decoded, $got);
    my $dup_band = {
        name        => "test band",
    };
    local $ENV{TEST_DUP_VALUE} = 'test band';
    warning_is {
        $res = $test->request(POST '/band/', $dup_band );
    } 'UNIQUE constraint failed: bands.name: test band';

    ok($res->is_success, 'still a 200-OK though');

    $got = decode_json($res->content);
    $expected = {
        data   => "",
        errors => [ {
            msg => "There is already an entry for 'test band' under Band",
            num => 409,
          },
        ],
    };
    eq_or_diff $got, $expected, 'return matches';
};


subtest 'GET /band/#' => sub{
    plan tests=>2;

    my ($res, $decoded, $got, $expected);

    $res  = $test->request( GET "/band/$Band_Id" );
    ok( $res->is_success, 'returned success' );

    $decoded = decode_json($res->content); 
    $got = $decoded->{data};
    $expected = {
        band_id     => $Band_Id,
        name        => $Band->name,
        url         => $Band->url,
        photo_url   => $Band->photo_url,
        created_ts  => $Created_Time,
        modified_ts => $Created_Time,
        is_deleted  => 0,
        talents     => [],
    };
    eq_or_diff $got, $expected, 'return matches';
};


subtest 'PUT /band/#' => sub {
    plan tests => 5;

    my ($res, $decoded, $got, $expected);
    my $edit_band = {
        name        => "new name",
        url         => "http://new-url",
        photo_url   => $Band->photo_url,
    };
    $ENV{TEST_NOW} += 100;
    $Modified_Time = get_now()->iso8601;
    $res = $test->request( PUT "/band/$Band_Id" , content => $edit_band);
    ok( $res->is_success, 'returned success' );
    
    $decoded = decode_json($res->content);
    $got = $decoded->{data};
    $expected = {
        band_id     => $Band_Id,
        name        => $edit_band->{name},
        url         => $edit_band->{url },
        photo_url   => $edit_band->{photo_url},
        created_ts  => $Created_Time,
        modified_ts => $Modified_Time,
        is_deleted  => 0,
        talents     => [],
    };
    eq_or_diff $got, $expected, 'return matches';

    $res  = $test->request( GET "/band/$Band_Id" );
    $decoded = decode_json($res->content); 
    $got = $decoded->{data};
    eq_or_diff $got, $expected, 'GET changed after PUT';

    # update our global band object
    $Band = $dbh->resultset('Band')->find($Band_Id);


    # demonstrate behavior on PUT with a non-existent pkey
    $test->put_ok('/band/45789', { content => $edit_band })
        or die $test->res->content;
    $decoded = decode_json($test->res->content);
    is $decoded->{errors}[0]{msg}, 'Nothing found for Band: primary key "45789"',
        'failed PUT has expected error msg' or diag explain $decoded;
};


subtest 'GET /bandAll' => sub{
    plan tests => 2;

    my ($res, $decoded, $got, $expected);
    $res  = $test->request( GET '/bandAll' );
    ok( $res->is_success, 'Returned success' );

    $decoded = decode_json($res->content);
    $got = $decoded->{data};
    $expected = [
      {
        band_id     => $Band_Id,
        name        => $Band->name,
        url         => $Band->url,
        photo_url   => $Band->photo_url,
        created_ts  => $Created_Time,
        modified_ts => $Modified_Time,
        is_deleted  => 0,
      },
    ];
    eq_or_diff $got, $expected, 'matches';
};
