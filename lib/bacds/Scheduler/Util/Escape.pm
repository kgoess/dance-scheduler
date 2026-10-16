=head1 NAME

bacds::Scheduler::Util::Escape - HTML-escape text that may already hold entities

=head1 SYNOPSIS

In a template:

    <span class="special-event-name"><% event.name | esc %></span>

In perl:

    use bacds::Scheduler::Util::Escape qw/escape_text/;
    my $safe = escape_text($band->name);

=head1 DESCRIPTION

Template Toolkit doesn't escape anything by default, and plain C<| html>
doesn't suit our data: names like "Geoffrey&rsquo;s Inner Circle" or
"Contra&#8212;beginner lesson" were typed in with HTML entities, and C<| html>
would turn them into a literal "&rsquo;" on the page.

C<escape_text> escapes C<< < > " >> and any C<&> that doesn't start an
entity, and leaves existing entities alone. An entity can't turn into markup,
so the result is safe in element text and in double-quoted attributes. Like
TT's C<| html> it leaves C<'> alone, so don't use it in single-quoted
attributes or inside javascript.

Use it for fields that are plain text, like names, cities, and URLs. Fields
meant to hold HTML (event short_desc and long_desc, the series sidebar and
display_text) are still output raw.

The filter is registered as C<esc> for the dancer app (see
bacds::Scheduler) and for the bin/ scripts that render the same templates,
via L</tt_filters>.

=cut

package bacds::Scheduler::Util::Escape;

use 5.16.0;
use warnings;

use Exporter 'import';
our @EXPORT_OK = qw/escape_text/;

sub escape_text {
    my ($s) = @_;
    return '' unless defined $s;

    $s =~ s{&(?!(?:[a-zA-Z][a-zA-Z0-9]{1,31}|#[0-9]{1,7}|#[xX][0-9a-fA-F]{1,6});)}{&amp;}g;
    $s =~ s{<}{&lt;}g;
    $s =~ s{>}{&gt;}g;
    $s =~ s{"}{&quot;}g;

    return $s;
}

=head2 tt_filters

Returns a hashref for Template Toolkit's FILTERS config option.

=cut

sub tt_filters {
    return { esc => \&escape_text };
}

1;
