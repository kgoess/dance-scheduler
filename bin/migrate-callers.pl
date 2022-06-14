#!/usr/bin/env perl

use 5.16.0;
use warnings;

use Data::Dump qw/dump/;

use bacds::Model::Event;# the old CSV schema
use bacds::Scheduler::Util::Db qw/get_dbh/;

my $dbh = get_dbh();

#list_callers($dbh);
add_callers($dbh);

sub list_callers {
    my ($dbh) = @_;

    my @old_events = bacds::Model::Event->load_all;
    my @older_events = map {
        say;
        bacds::Model::Event->load_all_from_old_schema(table => $_)
    } qw/schedule2021 /;
    my @really_old_events = map {
        say;
        bacds::Model::Event->load_all_from_really_old_schema(table => $_)
    } qw/schedule2020 schedule2019 schedule2018 schedule2017/;
    my $new = $dbh->resultset('Caller')->new({});

    my %seen;

    foreach my $old (@old_events, @older_events, @really_old_events) {

        next if $seen{$old->leader};

        say $old->leader;

        my $new = $dbh->resultset('Caller') ->new({});

        $new->name( $old->leader );
        $new->is_deleted(0);

        # we might want an is_active column
        #$new->is_active( $old->is_active );

        #$new->insert;
        $seen{$old->leader}++;
    }
}

sub add_callers {
    my ($dbh) = @_;

    my @callers = (
        'Alan Winston',
        'Alisa Dodson',
        'Brooke Friendly',
        'Bruce Hamilton',
        'Dilip Sequeira',
        'Bruce Herbold',
        'Cassiane Vlahos Mobley',
        'Cathleen Myers',
        'Celia Ramsay',
        'Charlie Fenton',
        'Claire Takemori',
        'David Newitt',
        'Eric Black',
        'Erik Hoffman',
        'Gary Thomas',
        'Kalia Kliban',
        'Kelsey Hartman',
        'Lise Dyckman',
        'Mary Luckhardt',
        'Nick Cuccia',
        'Rachel Pusey',
        'Ric Goldman',
        'Sharon Green',
        'Stephen White',
        'Susan Petrick',
        'Tom Roby',
        'Yoyo Zhou',
     );
     foreach my $caller (@callers) {

        my $new = $dbh->resultset('Caller') ->new({});

        say "doing caller $caller";

        $new->name( $caller );
        $new->is_deleted(0);

        # we might want an is_active column
        #$new->is_active( $old->is_active );

        $new->insert;
     }
}

