=head1 NAME

bacds::Scheduler::Model::FormQueue - Review queued "Add someone to your
membership" requests

=head1 SYNOPSIS

    use bacds::Scheduler::Model::FormQueue;

    my $queue = bacds::Scheduler::Model::FormQueue->new;

    for my $request (@{ $queue->pending }) {
        print $queue->format_request($request), "\n";
    }

    my $report = $queue->approve(19);
    print "$_\n" for @{ $report->{problems} }, @{ $report->{notes} };

    $queue->reject(20);

=head1 DESCRIPTION

Membership holders use the CiviCRM FormBuilder form
$bacds::Scheduler::CiviCRM::ADD_TO_MEMBERSHIP_FORM to ask for someone to be
added to their membership. The form has "Verify submission before
processing" turned on, so each request waits in CiviCRM's queue until
someone approves ("processes") or rejects it.

This is the logic behind bin/civicrm-check-form-queue.pl, which emails a
summary of waiting requests, and bin/civicrm-form-queue.pl, which approves
or rejects them from the command line. (CiviCRM's own submissions page
crashes on PHP < 8.3 as of 6.19.1; see
https://github.com/civicrm/civicrm-core/pull/37453.)

The form's entities are expected to be:

    Individual1    the holder, autofilled with the current user
    Individual2    the person to add, with an Email block
    Relationship1  Individual2 (contact_a) <relationship type> Individual1

=head1 METHODS

=cut

package bacds::Scheduler::Model::FormQueue;

use 5.32.1;
use warnings;

use Carp qw/croak/;

use bacds::Scheduler::CiviCRM;

=head2 new(%args)

Optional args: C<civi>, a bacds::Scheduler::CiviCRM object, and C<form>,
the form name (defaults to $bacds::Scheduler::CiviCRM::ADD_TO_MEMBERSHIP_FORM).

=cut

sub new {
    my ($class, %args) = @_;
    return bless {
        civi => $args{civi} // bacds::Scheduler::CiviCRM->new,
        form => $args{form} // $bacds::Scheduler::CiviCRM::ADD_TO_MEMBERSHIP_FORM,
    }, $class;
}

sub form { $_[0]{form} }

=head2 pending()

Returns an arrayref of the requests waiting for review, oldest first, as
described by L</get>.

=cut

sub pending {
    my ($self) = @_;

    my $submissions = $self->{civi}->get_form_submissions($self->{form}, status => 'Pending');
    return [ map { $self->_describe($_) } @$submissions ];
}

=head2 get($submission_id)

Returns one request, whatever its status, as a hashref:

    {
        id              => 19,
        submission_date => '2026-10-09 18:47:08',
        status          => 'Pending',
        holder_id       => 16,
        holder_name     => 'Pat Holder',
        new_first_name  => 'Robin',
        new_last_name   => 'Holder',
        new_email       => 'robin@example.com',   # '' if not given
        relationship    => 'Spouse of',           # '' if not in the data
        relationship_type_id => 2,                # undef if not in the data
        data            => { ... },               # the raw form values
    }

Dies if there's no such submission for this form.

=cut

sub get {
    my ($self, $submission_id) = @_;

    croak "Submission id must be a number, not '$submission_id'\n"
        unless $submission_id =~ /\A\d+\z/;
    my ($submission) = @{
        $self->{civi}->get_form_submissions($self->{form}, id => $submission_id)
    };
    croak "There's no submission $submission_id for the form $self->{form}\n"
        unless $submission;
    return $self->_describe($submission);
}

=head2 format_request($request)

Returns a few lines of plain text describing a request from L</get> or
L</pending>, for the email and the command-line tool.

=cut

sub format_request {
    my ($self, $r) = @_;

    my $new_person = join ' ', grep { length } $r->{new_first_name}, $r->{new_last_name};
    $new_person ||= '(no name given)';
    $new_person .= " <$r->{new_email}>" if length $r->{new_email};

    my $as = length $r->{relationship}
        ? "$r->{relationship} $r->{holder_name}"
        : '(relationship type set by the form)';

    return join "\n",
        "Request #$r->{id}, submitted $r->{submission_date} ($r->{status})",
        "  From: $r->{holder_name} (contact $r->{holder_id})",
        "  Add:  $new_person",
        "  As:   $as",
        '';
}

=head2 approve($submission_id)

Processes a pending request, then checks that it worked, since FormBuilder
doesn't report most failures. Returns

    {
        ok             => 1 or 0,  # 0 if there are any problems
        new_contact_id => 1234,    # undef if none was created or matched
        problems       => [ ... ], # things that went wrong
        notes          => [ ... ], # what happened
    }

The checks: the submission is now Processed; it created or matched a
contact for the new person; the holder side resolved to the contact who
submitted the form (it resolved to the processing user before CiviCRM
6.19); there's an active relationship of the requested type from the new
person to the holder; and CiviCRM gave the new person an inherited
membership from the holder. If it didn't, the problem says why if it can:
the holder has no current membership of their own, or theirs doesn't pass
to related contacts, or it's already at its own max_related (which stays
at whatever the type's limit was when the membership was created).

Dies if the request isn't pending.

=cut

sub approve {
    my ($self, $submission_id) = @_;

    my $before = $self->get($submission_id);
    croak "Request #$submission_id is $before->{status}, not Pending\n"
        unless $before->{status} eq 'Pending';

    $self->{civi}->process_form_submission($self->{form}, $submission_id);

    my $after = $self->get($submission_id);
    my (@problems, @notes);

    push @problems, "Request #$submission_id is still $after->{status} after processing"
        unless $after->{status} eq 'Processed';

    my $holder_id = $before->{holder_id};
    my $resolved_holder_id = _entity_id($after->{data}, 'Individual1');
    if (defined $resolved_holder_id && $resolved_holder_id != $holder_id) {
        push @problems, "The holder resolved to contact $resolved_holder_id, not "
            ."contact $holder_id who submitted the request";
    }

    my $new_id = _entity_id($after->{data}, 'Individual2');
    if (!defined $new_id) {
        push @problems, "CiviCRM didn't create or match a contact for the new person";
        return { ok => 0, new_contact_id => undef, problems => \@problems, notes => \@notes };
    }
    push @notes, "The new person is contact $new_id";

    my $type_id = $before->{relationship_type_id};
    my @active = grep {
        $_->{is_active}
            && (!defined $type_id || $_->{relationship_type_id} == $type_id)
    } @{ $self->{civi}->relationships_between($new_id, $holder_id) };
    if (@active) {
        push @notes, "Relationship $active[0]{id}: contact $new_id is "
            .($before->{relationship} || 'related to')." $before->{holder_name}";
    } else {
        push @problems, "There's no active "
            .($before->{relationship} ? "\"$before->{relationship}\" " : '')
            ."relationship from contact $new_id to $before->{holder_name} "
            ."(contact $holder_id)";
    }

    if (my $membership = $self->{civi}->inherited_membership_from($new_id, $holder_id)) {
        push @notes, "Contact $new_id has an inherited $membership->{type_name} "
            ."membership (#$membership->{id}, ends $membership->{end_date})";
    } else {
        push @problems, "Contact $new_id didn't get an inherited membership from "
            ."$before->{holder_name}: "
            .$self->_why_not_inherited($holder_id, $before->{holder_name});
    }

    return {
        ok             => @problems ? 0 : 1,
        new_contact_id => $new_id,
        problems       => \@problems,
        notes          => \@notes,
    };
}

=head2 reject($submission_id)

Marks a pending request as Rejected; nothing from it is saved. Dies if the
request isn't pending.

=cut

sub reject {
    my ($self, $submission_id) = @_;

    my $request = $self->get($submission_id);
    croak "Request #$submission_id is $request->{status}, not Pending\n"
        unless $request->{status} eq 'Pending';

    $self->{civi}->reject_form_submission($submission_id)
        or croak "CiviCRM didn't reject request #$submission_id\n";
}

# --- private helpers ---

# Explains why a new relative didn't get an inherited membership from the
# holder, as best we can tell
sub _why_not_inherited {
    my ($self, $holder_id, $holder_name) = @_;

    my @memberships = @{ $self->{civi}->membership_capacities($holder_id) };
    return "$holder_name has no current membership of their own"
        unless @memberships;

    my @shared = grep { $_->{passes_to_related} } @memberships;
    return "${holder_name}'s "
        .join(', ', map { "$_->{type_name} membership (#$_->{id})" } @memberships)
        ." doesn't pass to related contacts"
        unless @shared;

    my @full = grep {
        defined $_->{max_related} && $_->{inherited_count} >= $_->{max_related}
    } @shared;
    if (@full == @shared) {
        my $m = $full[0];
        return "${holder_name}'s $m->{type_name} membership (#$m->{id}) already "
            ."passes to $m->{inherited_count} people, its limit of "
            ."$m->{max_related}. (Each membership keeps the max_related its "
            ."type had when the membership was created.) Raise that "
            ."membership's max_related in CiviCRM, then edit and save the "
            ."relationship so CiviCRM creates the inherited membership";
    }
    return "CiviCRM should have created one from "
        .join(', ', map { "#$_->{id}" } @shared)
        ." but didn't";
}

sub _describe {
    my ($self, $submission) = @_;

    my $data   = $submission->{data};
    my $new    = $data->{Individual2}[0] // {};
    my $fields = $new->{fields} // {};
    my ($email) = grep { length } map { $_->{email} // '' }
        @{ $new->{joins}{Email} // [] };

    my $type_id = $data->{Relationship1}[0]{fields}{relationship_type_id};
    my $relationship = '';
    if (defined $type_id) {
        $self->{relationship_labels} //= $self->{civi}->relationship_type_labels;
        $relationship = $self->{relationship_labels}{$type_id}
            // "relationship type $type_id";
    }

    return {
        id                   => $submission->{id},
        submission_date      => $submission->{submission_date},
        status               => $submission->{status},
        holder_id            => $submission->{submitter_id},
        holder_name          => $submission->{submitter_name},
        new_first_name       => $fields->{first_name} // '',
        new_last_name        => $fields->{last_name}  // '',
        new_email            => $email // '',
        relationship         => $relationship,
        relationship_type_id => $type_id,
        data                 => $data,
    };
}

# The id CiviCRM saved for a form entity, from a processed submission's
# data. Processing adds it next to the entity's "fields", not in them;
# fields.id is whatever the form was prefilled with.
sub _entity_id {
    my ($data, $entity_name) = @_;
    return $data->{$entity_name}[0]{id};
}

1;
