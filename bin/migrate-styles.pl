#!/usr/bin/env perl

use 5.16.0;
use warnings;

use bacds::Scheduler::Util::Db qw/get_dbh/;

my $dbh = get_dbh();

my @styles =(
    {
        name=>'REGENCY',
    },
    {
        name=>'FAMILY',
    },
    {
        name=>'ONLINE',
    },
    {
        name=>'WOODSHED',
    },
    {
        name=>'ENGLISH',
    },
    {
        name=>'CONTRA',
    },
);

foreach my $style (@styles) {
    my $new = $dbh->resultset('Style')->new({});

    say "doing $style->{name}";

    $new->$_( $style->{$_} ) for qw/
        name
    /;
    $new->is_deleted(0);

    $new->insert;
}
