Here's how to load stuff from dbh directly.

```perl
use 5.16.0;
use warnings;

use Data::Dump qw/dump/;
use Test::More;

use bacds::Scheduler;
use bacds::Scheduler::Schema;
use bacds::Scheduler::Util::Db qw/get_dbh/;

unlink "testdb";

$ENV{TEST_DSN} = 'dbi:SQLite:dbname=testdb';
# load an on-disk test database and deploy the required tables
bacds::Scheduler::Schema->connection($ENV{TEST_DSN},'','');
bacds::Scheduler::Schema->load_namespaces;
bacds::Scheduler::Schema->deploy;

my $dbh = get_dbh();

my $contra = $dbh->resultset('Style')->new({
    name => 'CONTRA',
});
$contra->insert;
my $english = $dbh->resultset('Style')->new({
    name => 'ENGLISH',
});
$english->insert;

my $english_dance = $dbh->resultset('Event')->new({
    name => 'english dance #1',
    start_time => '2022-08-01T20:00',
    is_camp => 0,
    long_desc => 'this is long desc',
    short_desc => 'this is short desc',
    is_series_defaults => 0
});

$english_dance->insert;

#dump $dbh->resultset('Event')->result_source->_relationships;
# event_style_maps, not what we want
#$english_dance->set_from_related(event_styles_maps => $english);
#
#this uses the same ordering for each one, not what we want
#$english_dance->set_styles(
#    [$english],
#    {
#        ordering => 23,
#        created_ts => '2022-07-31T13:33',
#    }
#);
$english_dance->add_to_styles(
    $english,
    {
       ordering => 23,
       created_ts => '2022-07-31T13:33',
    },
);
$english_dance->add_to_styles(
    $contra,
    {
       ordering => 7,
       created_ts => '2022-07-31T13:33',
    },
);

my $retrieved_english = $dbh->resultset('Event')->find($english_dance->event_id);

say $retrieved_english->name, " event_id: ", $retrieved_english->id;
# output:
#     english dance #1 event_id: 1

say $_->name for $retrieved_english->styles;
# output:
#     CONTRA
#     ENGLISH

$retrieved_english->remove_from_styles($contra);
say "contra is removed";

my $retrieved_english_2 = $dbh->resultset('Event')->find($english_dance->event_id); 
say $_->name for $retrieved_english_2->styles;
# output:
#     ENGLISH
```
