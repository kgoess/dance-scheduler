package bacds::Scheduler::Route::Style;

use 5.16.0;
use warnings;

use Dancer2;
use Data::Dump qw/dump/;
use DateTime;

use bacds::Scheduler::Schema;
use bacds::Scheduler::Util::Db qw/get_dbh/;

sub get_styles {
    my $dbh = get_dbh();

    my $resultset = $dbh->resultset('Style')->search();

    $resultset or die "empty set"; #TODO: More gracefully

    my @styles;

    while (my $style = $resultset->next) {
        push @styles, style_row_to_result($style);
    }

    return \@styles;
};

sub get_style() {
    my ($self, $style_id) = @_;

    my $dbh = get_dbh();

    my $style = $dbh->resultset('Style')->find($style_id)
        or return false;

    return style_row_to_result($style);
};

sub post_style() {
    my ($self, $data) = @_;
    my $dbh = get_dbh();

    my $style = $dbh->resultset('Style')->new({});

    $style->name($data->{name});
    #TODO: Move this to the schema
    $style->modified_ts(DateTime->now);
    $style->created_ts(DateTime->now);

    $style->insert(); #TODO: check for failure
    #TODO: make it so that we are returning the new data from the db, instead of what was sent.
    return style_row_to_result($style);
};


sub put_style() {
    my ($self, $data) = @_;
    my $dbh = get_dbh();

    my $resultset = $dbh->resultset('Style')->search(
        { style_id=> { '=' => $data->{style_id} } } # SQL::Abstract::Classic
    );

    $resultset or return 0; #TODO: More robust error handling
    my $style = $resultset->next; #it's searching on primary key, there will only be 0 or 1 result
    $style->name($data->{name});
    $style->modified_ts(DateTime->now); #TODO: Move this to the schema

    $style->update(); #TODO: check for failure
    
    return style_row_to_result($style);
};


sub style_row_to_result {
    my ($style) = @_;

    my $result = {};

    foreach my $field (qw/
        style_id
        name
        created_ts
        modified_ts/){
        $result->{$field} = $style->$field;
    };

    foreach my $datetime (qw/created_ts modified_ts/){
        next unless $result->{$datetime};
        $result->{$datetime} = $result->{$datetime}->iso8601;
    };

    return $result;
}

true;
