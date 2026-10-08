
# Tests for bacds::Scheduler::CiviCRM itself, with the CiviCRM REST API
# replaced by canned responses (t/530-member-portal.t mocks this whole class
# instead).

use 5.32.1;
use warnings;

use HTTP::Response;
use JSON::MaybeXS qw/decode_json/;
use Test::More;
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
             'membership_type_id:name' => 'Family', owner_membership_id => undef },
    735 => { id => 868, end_date => '2027-03-31',
             'membership_type_id:name' => 'Family', owner_membership_id => 867,
             'owner_membership_id.contact_id.display_name' => 'Pat Holder' },
    # an old lapsed membership of their own, but now a spouse in a Family
    100 => { id => 50, end_date => '2020-01-01',
             'membership_type_id:name' => 'Individual', owner_membership_id => undef },
);

# Keep the real one for test_call_v4_url_encodes_params
my $real_call_v4 = \&bacds::Scheduler::CiviCRM::_call_v4;

{
    no warnings 'redefine';
    *bacds::Scheduler::CiviCRM::_call_v4 = sub {
        my ($self, $entity, $action, $params) = @_;
        my $where = $params->{where} // [];

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
test_call_v4_url_encodes_params();

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
        { contact_id => 100, display_name => 'Contact 100', relationship => 'Spouse of' },
        { contact_id => 101, display_name => 'Contact 101', relationship => 'Household Member is' },
    ], "lists who the holder's membership covers, with their side of the relationship";
}

sub test_get_contact_own_membership {
    my $civi = bacds::Scheduler::CiviCRM->new;
    my $contact = $civi->get_contact(16);

    is_deeply [ map { $_->{contact_id} } @{ $contact->{membership_covers} } ], [100, 101],
        'holder: lists who the membership covers';
    is $contact->{membership_max_related}, 10, 'holder: max_related';

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

sub _rel {
    my ($a, $b, $type, $name_a_b, $name_b_a, $extra) = @_;
    return {
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
