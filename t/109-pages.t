use 5.16.0;
use warnings;

use Data::Dump qw/dump/;
use HTTP::Request::Common;
use JSON::MaybeXS qw/decode_json/;
use Plack::Test;
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

my $Page;
my $Page_Id;
my $Created_Time;
my $Modified_Time;


subtest 'Invalid GET /page/1' => sub {
    plan tests => 2;

    my ($res, $decoded, $got, $expected);
    $res = $test->request( GET '/page/1' );
    ok($res->is_success, 'returned success');

    $decoded = decode_json($res->content);
    $expected = {
        data => '',
        errors => [{
            msg => 'Nothing found for Page: primary key "1"',
            num => 404,
        }]
    };
    eq_or_diff $decoded, $expected, 'error msg matches';
};

subtest 'POST /page' => sub {
    plan tests => 2;

    my ($expected, $res, $decoded, $got);
    my $new_page = {
        title            => "test page",
        url_path         => "/some/path",
        short_desc       => "this is the short_desc",
        body       => "Hoc est enim corpus meum",
    #    page_id          => '', # the webapp sends title=test+page&page_id=
    };
    $ENV{TEST_NOW} = 1651112285;
    $Created_Time = get_now()->iso8601;
    $res = $test->request(POST '/page/', $new_page );
    ok($res->is_success, 'returned success');

    $decoded = decode_json($res->content);
    $got = $decoded->{data};
    $expected = {
        page_id    => 1,
        title            => $new_page->{title},
        url_path         => $new_page->{url_path},
        short_desc       => $new_page->{short_desc},
        body       => $new_page->{body},
        sidebar       => undef,
        created_ts  => $Created_Time,
        modified_ts => $Created_Time,
        is_deleted  => 0,
    };
    eq_or_diff $got, $expected, 'return matches';

    # now save it for the subsequent tests
    $Page = $dbh->resultset('Page')->find($decoded->{data}{page_id});
    $Page_Id = $Page->page_id;
};

subtest 'POST /page duplicate' => sub {
    plan tests => 3;

    my ($expected, $res, $decoded, $got);
    my $dup_page = {
        abbreviation => "TPO",
        title        => "test page",
        url_path        => "/some/path",
        body        => "test page",
        short_desc        => "test page",
    };
    local $ENV{TEST_DUP_VALUE} = 'test page';
    warning_is {
        $res = $test->request(POST '/page/', $dup_page );
    } 'UNIQUE constraint failed: pages.url_path: test page';

    ok($res->is_success, 'still a 200-OK though');

    $got = decode_json($res->content);
    $expected = {
        data   => "",
        errors => [ {
            msg => "There is already an entry for 'test page' under Page",
            num => 409,
          },
        ],
    };
    eq_or_diff $got, $expected, 'return matches';
};

subtest 'GET /page/#' => sub {
    plan tests => 2;

    my ($res, $decoded, $got, $expected);

    $res  = $test->request( GET "/page/$Page_Id" );
    ok( $res->is_success, 'returned success' );

    $decoded = decode_json($res->content); 
    $got = $decoded->{data};
    $expected = {
        page_id          => $Page_Id,
        title            => $Page->title,
        url_path         => $Page->url_path,
        short_desc         => $Page->short_desc,
        body         => $Page->body,
        sidebar         => undef,
        created_ts  => $Created_Time,
        modified_ts => $Created_Time,
        is_deleted  => 0,
    };
    eq_or_diff $got, $expected, 'return matches';
};


subtest 'PUT /page/#' => sub {
    plan tests => 5;

    my ($res, $decoded, $got, $expected);
    my $edit_page = {
        title        => "new name",
        abbreviation => "NNO",
    };
    $ENV{TEST_NOW} += 100;
    $Modified_Time = get_now()->iso8601;
    $res = $test->request( PUT "/page/$Page_Id" , content => $edit_page);
    ok( $res->is_success, 'returned success' );
    
    $decoded = decode_json($res->content);
    $got = $decoded->{data};
    $expected = {
        page_id          => $Page_Id,
        title            => $edit_page->{title},
        url_path         => $Page->url_path,
        short_desc         => $Page->short_desc,
        body         => $Page->body,
        sidebar         => undef,
        created_ts  => $Created_Time,
        modified_ts => $Modified_Time,
        is_deleted  => 0,
    };
    eq_or_diff $got, $expected, 'return matches';

    $res  = $test->request( GET "/page/$Page_Id" );
    $decoded = decode_json($res->content); 
    $got = $decoded->{data};
    eq_or_diff $got, $expected, 'GET changed after PUT';

    # update our global page object
    $Page = $dbh->resultset('Page')->find($Page_Id);


    # demonstrate behavior on PUT with a non-existent pkey
    $test->put_ok('/page/45789', { content => $edit_page })
        or die $test->res->content;
    $decoded = decode_json($test->res->content);
    is $decoded->{errors}[0]{msg}, 'Nothing found for Page: primary key "45789"',
        'failed PUT has expected error msg' or diag explain $decoded;
};


subtest 'GET /pageAll' => sub{
    plan tests => 2;

    my ($res, $decoded, $got, $expected);
    $res  = $test->request( GET '/pageAll' );
    ok( $res->is_success, 'Returned success' );

    $decoded = decode_json($res->content);
    $got = $decoded->{data};
    $expected = [
      {
        page_id          => $Page_Id,
        title            => $Page->title,
        url_path              => $Page->url_path,
        short_desc              => $Page->short_desc,
        body              => $Page->body,
        sidebar         => undef,
        created_ts  => $Created_Time,
        modified_ts => $Modified_Time,
        is_deleted  => 0,
      },
    ];
    eq_or_diff $got, $expected, 'matches';
};
