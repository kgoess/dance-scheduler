=head1 NAME

bacds::Scheduler::Util::Results - Package to collect any errors and format the results

=head1 SYNOPSIS

    my $results = bacds::Scheduler::Util::Results->new;

    $results->data($array_pointer);
    
    return $results->format;

    outputs JSON like:
    "data": [
        ...
    ],
    "errors": [
      {
        msg: "big fail",
        num: 1234
      }
    ],


=cut

package bacds::Scheduler::Util::Results;
use 5.16.0;
use warnings;

use Dancer2;
use Data::Dump qw/dump/;
use Encode qw/decode_utf8/;
use Class::Accessor::Lite (
    new => 0,
    rw => [ qw(data errors) ],
);

sub new {
    return bless { data => '', errors => [] };
}

sub add_error {
    my ($self, $num, $msg) = @_;
    push @{$self->errors}, {
        msg => $msg,
        num => $num,
    };
}

sub format {
    my ($self) = @_;
    my $json_str = encode_json({
        data => $self->data,
        errors => [
            map { {
                msg => $_->{msg},
                num => $_->{num},
            } } @{$self->errors}
        ],
    });
    # encode_json returns utf8 octets. Apparently the dancer2 handlers
    # expect logical perl characters which *they* can then utf8-encode.
    # Lacking this call to decode-utf8 the Dancer2 handlers double-encode
    # the output. Maybe there's a way to tell Dancer2 to not do that?
    return decode_utf8 $json_str;
}

1;
