
use 5.16.0;
use warnings;

use Data::Dump qw/dump/;
use Test::More tests => 2;

use bacds::Scheduler::Util::Db qw/get_dbh/;
use bacds::Scheduler::Util::Test qw/setup_test_db get_tester/;
use bacds::Scheduler::Util::Time qw/get_now/;

use bacds::Scheduler::Model::DanceFinder;

setup_test_db;

my $dbh = get_dbh();

$ENV{TEST_NOW} = 1651112285;

my $i = 0;

my $Event1 = $dbh->resultset('Event')->new({
    name => 'test event 1',
    synthetic_name => 'test event 1 synthname',
    start_date => get_now->ymd('-'),
    start_time => '20:00',
});
$Event1->insert;
my $Event2 = $dbh->resultset('Event')->new({
    name => 'test event 2',
    synthetic_name => 'test event 2 synthname',
    start_date => get_now->ymd('-'),
    start_time => '20:00',
});
$Event2->insert;


my $Band1 = $dbh->resultset('Band')->new({
    name => 'test band 1',
});
$Band1->insert;
$Band1->add_to_events($Event1, {
    ordering => $i++,
     created_ts => '2022-07-31T13:33',
});
my $Band2 = $dbh->resultset('Band')->new({
    name => 'test band 2',
});
$Band2->insert;
$Band2->add_to_events($Event1,
  {  ordering => $i++,
     created_ts => '2022-07-31T13:33',
});

my $Muso1 = $dbh->resultset('Talent')->new({
    name => 'muso 1',
});
$Muso1->insert;
$Muso1->add_to_bands($Band1, {
     ordering => $i++,
     created_ts => '2022-07-31T13:33',
});
my $Muso2 = $dbh->resultset('Talent')->new({
    name => 'muso 2',
});
$Muso2->insert;
$Muso2->add_to_bands($Band1, {
     ordering => $i++,
     created_ts => '2022-07-31T13:33',
});
my $Muso3 = $dbh->resultset('Talent')->new({
    name => 'muso 3',
});
$Muso3->insert;
# Muso3 isn't in a band, they're just sitting in on event2
$Muso3->add_to_events($Event1, {
     ordering => $i++,
     created_ts => '2022-07-31T13:33',
});

test_model();
# TBD test_endpoint();


# not a complete test
sub test_model {

    my $data = bacds::Scheduler::Model::DanceFinder->get_events();

    my @found_band_names;
    foreach my $band_id (sort keys %{$data->{bands}}) {
        my $band = $data->{bands}{$band_id};
        push @found_band_names, $band->name;
    }
    @found_band_names = sort @found_band_names;

    is_deeply \@found_band_names, ["test band 1", "test band 2"];


    my @found_muso_names;
    foreach my $muso_id (sort keys %{$data->{musos}}) {
        my $muso = $data->{musos}{$muso_id};
        push @found_muso_names, $muso->name;
    }
    @found_muso_names = sort @found_muso_names;

    is_deeply \@found_muso_names, ["muso 1", "muso 2", "muso 3"]
        or dump \@found_muso_names;
}

