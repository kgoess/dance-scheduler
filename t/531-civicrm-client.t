
# Tests for bacds::Scheduler::CiviCRM itself, with the CiviCRM REST API
# replaced by canned responses (t/530-member-portal.t mocks this whole class
# instead).

use 5.32.1;
use warnings;
use utf8;

use DateTime;
use HTTP::Response;
use JSON::MaybeXS qw/decode_json/;
use Test::More;
use Test::Warn;
use URI;

use bacds::Scheduler::CiviCRM;

{
    no warnings 'redefine';
    *bacds::Scheduler::CiviCRM::_read_private_file = sub { 'fake' };
}
$bacds::Scheduler::CiviCRM::MOCK_API_KEY = 'fake';

# The holder, contact 16, has Family membership 867. Family memberships pass
# to related contacts through these relationship types and owner directions
# (copied from bacds.civicrm.org):
#   1 Child of / Parent of               a_b and b_a
#   8 Household Member of / ... is       a_b (owner is contact_a)
#   3 Partner of                         a_b (same name both ways)
#   2 Spouse of                          a_b (same name both ways)
my %membership_types = (
    values => [{
        id                     => 2,
        relationship_type_id   => [1, 8, 1, 3, 2],
        relationship_direction => [qw(a_b a_b b_a a_b a_b)],
        max_related            => 10,
    }],
);
my %relationships = (
    values => [
        # 100 is the spouse, with the holder on the b side: counts because
        # "Spouse of" is the same both ways
        _rel(100, 16,  2, 'Spouse of', 'Spouse of'),
        # 101: holder on the a side of "Household Member of": listed
        _rel(16,  101, 8, 'Household Member of', 'Household Member is'),
        # 102: holder on the b side of "Household Member of": not listed
        _rel(102, 16,  8, 'Household Member of', 'Household Member is'),
        # 103: a relationship type Family doesn't list at all
        _rel(103, 16,  4, 'Employee of', 'Employer of'),
        # 104: would count, but the contact is in the trash
        _rel(104, 16,  2, 'Spouse of', 'Spouse of', { 'contact_id_a.is_deleted' => 1 }),
    ],
);
my %owner_memberships = (
    values => [{
        id                        => 867,
        contact_id                => 16,
        end_date                  => '2027-03-31',
        membership_type_id        => 2,
        'membership_type_id:name' => 'Family',
        'contact_id.display_name' => 'Pat Holder',
    }],
);

# Canned responses for get_contact, keyed by contact id
my %own_membership = (
    16  => { id => 867, end_date => '2027-03-31', membership_type_id => 2,
             'membership_type_id:name' => 'Family', owner_membership_id => undef,
             max_related => 10 },
    735 => { id => 868, end_date => '2027-03-31',
             'membership_type_id:name' => 'Family', owner_membership_id => 867,
             'owner_membership_id.contact_id.display_name' => 'Pat Holder' },
    # an old lapsed membership of their own, but now a spouse in a Family
    100 => { id => 50, end_date => '2020-01-01',
             'membership_type_id:name' => 'Individual', owner_membership_id => undef },
);

my @relationship_updates;

# What WorkflowMessage.render returns, and the params it was called with
our $rendered_text = 'https://bacds.civicrm.org/civicrm/add-family-member?_aff=Bearer%20abc.def.ghi';
my @render_calls;
# Canned Email.get rows, standing in for whatever CiviCRM's case- and
# accent-insensitive match returns
my @email_rows;

# Keep the real one for test_call_v4_url_encodes_params
my $real_call_v4 = \&bacds::Scheduler::CiviCRM::_call_v4;

# How many current memberships are inherited from any membership
our $inherited_count = 2;

# FormBuilder submission calls, and what they return
my (@form_queue_calls, $form_queue_response);

{
    no warnings 'redefine';
    *bacds::Scheduler::CiviCRM::_call_v4 = sub {
        my ($self, $entity, $action, $params) = @_;
        my $where = $params->{where} // [];

        if ("$entity.$action" eq 'Relationship.update') {
            push @relationship_updates, $params;
            return { values => [] };
        }
        if ($entity eq 'AfformSubmission' || "$entity.$action" eq 'Afform.process') {
            push @form_queue_calls, ["$entity.$action", $params];
            return $form_queue_response;
        }
        if ("$entity.$action" eq 'WorkflowMessage.render') {
            push @render_calls, $params;
            return { values => [{ subject => '', text => $rendered_text, html => '' }] };
        }
        return { values => [ @email_rows ] } if $entity eq 'Email';
        return \%membership_types if $entity eq 'MembershipType';
        return \%relationships    if $entity eq 'Relationship';
        return { values => [{ checksum => 'abc_123_1' }] }
            if "$entity.$action" eq 'Contact.getChecksum';
        return { values => [{ first_name => 'Wanda' }] } if $entity eq 'Contact';
        return { values => [ map {
            { id => $_, name => "Field_$_", data_type => 'Boolean',
              'custom_group_id:name' => 'AdditionalContactFields' }
        } 3 .. 8 ] } if $entity eq 'CustomField';
        return { values => [] } if $entity eq 'Address' || $entity eq 'Phone';

        if ($entity eq 'Membership') {
            # counting a membership's current inherited memberships
            return { values => [], count => $inherited_count }
                if $where->[0][0] eq 'owner_membership_id';
            # the owner lookup filters by a list of contact ids
            return \%owner_memberships if $where->[0][1] eq 'IN';
            my $own = $own_membership{ $where->[0][2] };
            return { values => [ $own // () ] };
        }
        die "unexpected call $entity.$action";
    };
}

test_owner_memberships_via_relationship();
test_get_contact_own_membership();
test_get_contact_inherited_membership();
test_get_contact_through_relationship();
test_covered_by_membership();
test_end_covered_relationships();
test_add_to_membership_url();
test_add_to_membership_url_failure();
test_get_contact_at_max_related();
test_get_contact_uses_membership_max_related();
test_membership_capacities();
test_call_v4_url_encodes_params();
test_form_submission_calls();
test_find_member_contacts_returns_stored_email();
test_find_member_contacts_ignores_lookalike_email();
test_find_related_contacts_returns_stored_email();
test_find_related_contacts_ignores_lookalike_email();

done_testing;

sub test_owner_memberships_via_relationship {
    my $civi = bacds::Scheduler::CiviCRM->new;
    my $covered = $civi->_owner_memberships_via_relationship([100, 101, 102, 103]);

    is_deeply [sort keys %$covered], [100, 101],
        'only relationships the membership type lists, in the right direction';
    is_deeply $covered->{100}, [{
        id         => 867,
        end_date   => '2027-03-31',
        type_name  => 'Family',
        owner_name => 'Pat Holder',
    }], "spouse is covered by the holder's membership";
}

sub test_covered_by_membership {
    my $civi = bacds::Scheduler::CiviCRM->new;
    my $result = $civi->_covered_by_membership(16, 2);

    is $result->{max_related}, 10, 'max_related comes from the membership type';
    is_deeply $result->{covered}, [
        { contact_id => 100, display_name => 'Contact 100', relationship => 'Spouse of',
          relationship_ids => [5100] },
        { contact_id => 101, display_name => 'Contact 101', relationship => 'Household Member is',
          relationship_ids => [5101] },
    ], "lists who the holder's membership covers, with their side of the relationship";
}

sub test_end_covered_relationships {
    my $civi = bacds::Scheduler::CiviCRM->new;
    @relationship_updates = ();

    my $ended;
    warnings_like {
        $ended = $civi->end_covered_relationships(16, [100, 102, 999]);
    } [
        qr{contact 102 isn't covered by a membership held by 16, skipping},
        qr{contact 999 isn't covered by a membership held by 16, skipping},
    ], 'warns about contacts the membership does not cover';

    is $ended, 1, 'ended one relationship';
    is scalar @relationship_updates, 1, 'one Relationship.update call';
    is_deeply $relationship_updates[0]{where}, [['id', 'IN', [5100]]],
        "only the covered spouse's relationship";
    is_deeply $relationship_updates[0]{values}, {
        is_active => \0,
        end_date  => DateTime->now->ymd,
    }, 'set inactive with an end date, not deleted';

    @relationship_updates = ();
    warning_like {
        $ended = $civi->end_covered_relationships(16, [103]);
    } qr{contact 103 isn't covered}, 'warns for an unlisted relationship type';
    is $ended, 0, 'nothing ended';
    is scalar @relationship_updates, 0, 'no Relationship.update call';
}

sub test_add_to_membership_url {
    my $civi = bacds::Scheduler::CiviCRM->new;
    @render_calls = ();

    is $civi->add_to_membership_url(16), $rendered_text, 'returns the signed form link';
    is_deeply $render_calls[0], {
        workflow        => 'generic',
        messageTemplate => {
            msg_subject => '',
            msg_text    => '{form.afformAddSomeoneToYourMembershipUrl}',
            msg_html    => '',
        },
        values          => { contactID => 16 },
    }, 'renders just the form URL token for the contact';
}

sub test_add_to_membership_url_failure {
    my $civi = bacds::Scheduler::CiviCRM->new;

    # CiviCRM renders an unknown form token as '', e.g. if the form was
    # renamed or lost its Message Tokens placement
    local $rendered_text = '';
    my $url;
    warning_like { $url = $civi->add_to_membership_url(16) }
        qr{can't get link for contact 16: .*isn't a signed form link},
        'warns when the token does not render to a link';
    is $url, '', 'and returns no link';
}

sub test_get_contact_uses_membership_max_related {
    my $civi = bacds::Scheduler::CiviCRM->new;

    # The type now allows 10, but this membership was created when it was 2
    local $membership_types{values}[0]{max_related} = 10;
    local $own_membership{16}{max_related} = 2;
    my $contact = $civi->get_contact(16);
    is $contact->{membership_max_related}, 2, "uses the membership's own limit, not the type's";
    is $contact->{membership_at_max_related}, 1, '... so it is at its limit';

    local $own_membership{16}{max_related} = undef;
    $contact = $civi->get_contact(16);
    is $contact->{membership_max_related}, undef, 'NULL max_related means no limit';
    is $contact->{membership_at_max_related}, 0, '... and never at the limit';
}

sub test_membership_capacities {
    my $civi = bacds::Scheduler::CiviCRM->new;
    local $own_membership{16}{max_related} = 2;
    local $inherited_count = 2;

    is_deeply $civi->membership_capacities(16), [{
        id => 867, type_name => 'Family', passes_to_related => 1,
        max_related => 2, inherited_count => 2,
    }], "the holder's membership, its own limit, and how many inherit from it";
}

sub test_get_contact_at_max_related {
    my $civi = bacds::Scheduler::CiviCRM->new;
    local $own_membership{16}{max_related} = 2;  # 100 and 101 are covered

    my $contact = $civi->get_contact(16);
    is $contact->{membership_at_max_related}, 1, 'at limit: flagged';
    is $contact->{membership_add_url}, '', 'at limit: no add link';
}

sub test_get_contact_own_membership {
    my $civi = bacds::Scheduler::CiviCRM->new;
    my $contact = $civi->get_contact(16);

    is_deeply [ map { $_->{contact_id} } @{ $contact->{membership_covers} } ], [100, 101],
        'holder: lists who the membership covers';
    is $contact->{membership_max_related}, 10, 'holder: max_related';
    is $contact->{membership_add_url}, $rendered_text, 'holder: gets the add link';
    is $contact->{membership_at_max_related}, 0, 'holder: not at the limit';

    is $contact->{membership_id}, 867, 'holder: own membership';
    is $contact->{membership_owner_name}, '', 'holder: no owner name';
    like $contact->{membership_payment_url}, qr{cid=16&mid=867&cs=abc_123_1},
        'holder: gets a payment link';
}

sub test_get_contact_inherited_membership {
    my $civi = bacds::Scheduler::CiviCRM->new;
    my $contact = $civi->get_contact(735);

    is $contact->{membership_id}, 868, 'inherited: their inherited membership';
    is $contact->{membership_owner_name}, 'Pat Holder', 'inherited: names the holder';
    is $contact->{membership_payment_url}, '', 'inherited: no payment link';
    is_deeply $contact->{membership_covers}, [], 'inherited: no covered list';
    is $contact->{membership_add_url}, '', 'inherited: no add link';
}

sub test_get_contact_through_relationship {
    my $civi = bacds::Scheduler::CiviCRM->new;
    my $contact = $civi->get_contact(100);

    is $contact->{membership_id}, 867,
        "related: the holder's current membership beats their own lapsed one";
    is $contact->{membership_type_name}, 'Family', 'related: membership type';
    is $contact->{membership_end}, '2027-03-31', 'related: end date';
    is $contact->{membership_is_active}, 1, 'related: active';
    is $contact->{membership_owner_name}, 'Pat Holder', 'related: names the holder';
    is $contact->{membership_payment_url}, '', 'related: no payment link';
}

sub test_form_submission_calls {
    my $civi = bacds::Scheduler::CiviCRM->new;

    @form_queue_calls = ();
    $form_queue_response = { values => [{
        id => 19, contact_id => 16, 'contact_id.display_name' => 'Pat Holder',
        submission_date => '2026-10-09 18:47:08', 'status_id:name' => 'Pending',
        data => { Individual2 => [] },
    }] };
    my $submissions = $civi->get_form_submissions('afformTest', status => 'Pending', id => '19');
    is_deeply $form_queue_calls[0][1]{where}, [
        ['afform_name',    '=', 'afformTest'],
        ['status_id:name', '=', 'Pending'],
        ['id',             '=', 19],
    ], 'get_form_submissions: filters by form, status, and id';
    is_deeply $submissions, [{
        id => 19, submitter_id => 16, submitter_name => 'Pat Holder',
        submission_date => '2026-10-09 18:47:08', status => 'Pending',
        data => { Individual2 => [] },
    }], 'get_form_submissions: renames the fields';

    @form_queue_calls = ();
    $form_queue_response = { values => [] };
    $civi->process_form_submission('afformTest', '19');
    is_deeply \@form_queue_calls,
        [['Afform.process', { name => 'afformTest', submissionId => 19 }]],
        'process_form_submission: calls Afform.process';

    @form_queue_calls = ();
    $form_queue_response = { values => [{ id => 19 }] };
    is $civi->reject_form_submission(19), 1, 'reject_form_submission: returns the count';
    is_deeply $form_queue_calls[0], ['AfformSubmission.update', {
        values => { 'status_id:name' => 'Rejected' },
        where  => [['id', '=', 19], ['status_id:name', '=', 'Pending']],
    }], 'reject_form_submission: only rejects it if pending';
}

# A "+" in an unencoded form body arrives as a space, so plus-addressed
# emails never matched and phone numbers lost their "+".
sub test_call_v4_url_encodes_params {
    my $civi = bacds::Scheduler::CiviCRM->new;
    my $req;
    $civi->{ua} = bless { on_request => sub { $req = shift } }, 'FakeUA';

    $civi->$real_call_v4('Email', 'get', {
        where => [['email', '=', 'pat+bacds@example.com']],
    });

    my %form = URI->new('?' . $req->content)->query_form;
    is decode_json($form{params})->{where}[0][2], 'pat+bacds@example.com',
        'a "+" in a param survives form decoding';
}

sub test_find_member_contacts_returns_stored_email {
    my $civi = bacds::Scheduler::CiviCRM->new;

    # The membership join gives one row per membership, so contact 42 shows
    # up twice
    @email_rows = (
        _email_row(42, 'Alice', 'alice@example.com'),
        _email_row(42, 'Alice', 'alice@example.com'),
    );
    my $contacts = $civi->find_member_contacts_by_email('ALICE@Example.com');

    is_deeply $contacts, [{
        contact_id   => 42,
        display_name => 'Alice',
        email        => 'alice@example.com',
    }], 'returns each contact once, with the address stored in CiviCRM';
}

sub test_find_member_contacts_ignores_lookalike_email {
    my $civi = bacds::Scheduler::CiviCRM->new;

    @email_rows = (_email_row(42, 'Alice', 'alice@example.com'));
    my $contacts = $civi->find_member_contacts_by_email('alice@exámple.com');

    is_deeply $contacts, [],
        'an accent-insensitive collation match is not treated as the same address';
}

sub test_find_related_contacts_returns_stored_email {
    my $civi = bacds::Scheduler::CiviCRM->new;

    # 100 is covered by the holder's Family membership (see %relationships)
    @email_rows = (_email_row(100, 'Sam Spouse', 'spouse@example.com'));
    my $contacts = $civi->find_related_member_contacts_by_email('Spouse@example.com');

    is_deeply $contacts, [{
        contact_id   => 100,
        display_name => 'Sam Spouse',
        email        => 'spouse@example.com',
    }], 'related contact comes back with the address stored in CiviCRM';
}

sub test_find_related_contacts_ignores_lookalike_email {
    my $civi = bacds::Scheduler::CiviCRM->new;

    @email_rows = (_email_row(100, 'Sam Spouse', 'spouse@example.com'));
    my $contacts = $civi->find_related_member_contacts_by_email('spöuse@example.com');

    is_deeply $contacts, [],
        'lookalike address does not match a related contact either';
}

sub _email_row {
    my ($contact_id, $display_name, $email) = @_;
    return {
        contact_id                => $contact_id,
        'contact_id.display_name' => $display_name,
        email                     => $email,
    };
}

sub _rel {
    my ($a, $b, $type, $name_a_b, $name_b_a, $extra) = @_;
    return {
        id                               => 5000 + $a + $b - 16,
        contact_id_a                     => $a,
        contact_id_b                     => $b,
        'contact_id_a.display_name'      => "Contact $a",
        'contact_id_b.display_name'      => "Contact $b",
        'contact_id_a.is_deleted'        => 0,
        'contact_id_b.is_deleted'        => 0,
        relationship_type_id             => $type,
        'relationship_type_id.name_a_b'  => $name_a_b,
        'relationship_type_id.name_b_a'  => $name_b_a,
        'relationship_type_id.label_a_b' => $name_a_b,
        'relationship_type_id.label_b_a' => $name_b_a,
        %{ $extra // {} },
    };
}

package FakeUA;

sub request {
    my ($self, $req) = @_;
    $self->{on_request}->($req);
    return HTTP::Response->new(200, 'OK', [], '{"values":[]}');
}
