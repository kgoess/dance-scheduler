=head1 NAME

bacds::Scheduler::CiviCRM - Client for the CiviCRM REST API

=head1 SYNOPSIS

    my $civi = bacds::Scheduler::CiviCRM->new;

    my $contact = $civi->find_member_contacts_by_email('member@example.com');
    my $contact_id = $contacts->[0]{contact_id}
    my $contact    = $civi->get_contact($contact_id);
    $civi->update_contact($contact_id, \%new_data);
    $civi->send_magic_link_email($contact_id, $email, $display_name, $url);

=head1 DESCRIPTION

Wraps CiviCRM's REST API for the member self-service portal.

Data operations use APIv4 (POST /civicrm/ajax/api4/{Entity}/{Action}).

Email sending uses APIv3 MessageTemplate.send (POST /civicrm/ajax/rest),
which is not available in APIv4.

  Member browser          dance-scheduler (bacds.org)       CiviCRM (bacds.civicrm.org)
        |                          |                                  |
        |-- GET /member ---------->|                                  |
        |<- email form ------------|                                  |
        |                          |                                  |
        |-- POST /member/request ->|-- Email.get (find by email) ---->|
        |                          |<- contact_id --------------------|
        |                          | generate token, store in DB      |
        |                          |-- MessageTemplate.send --------->|
        |                          |   (contact_id, tplParams:{url})  |-- sends email -->member
        |<- "check your inbox" ----|                                  |
        |                          |                                  |
        |-- GET /member/portal --->|                                  |
        |   ?token=XXX             | validate token                   |
        |                          |-- Contact.get ------------------>|
        |                          |   Address.get, Phone.get         |
        |<- pre-filled form -------|<- contact data ------------------|
        |                          |                                  |
        |-- POST /member/portal -->| validate token                   |
        |   (updated fields)       |-- Contact.create (update) ------>|
        |                          |   Address.create, Phone.create   |
        |<- success page ----------|                                  |

=head2 Configuration

Two private files are required (following the same pattern as other secrets
in this app):

  Production: /var/www/bacds.org/dance-scheduler/private/civicrm-api-key
  Dev:        ~/.civicrm-api-key

  Production: /var/www/bacds.org/dance-scheduler/private/civicrm-magic-link-template-id
  Dev:        ~/.civicrm-magic-link-template-id

Each file contains a single value on one line. The template ID is the numeric
ID of the CiviCRM message template used to send the magic link email. The
template should include a {$selfservice_url} Smarty variable for the link.

The API key you generate and assign to a Contact record. That Contact has to
have Administrator permissions or at least enough permissions to view and edit
Contact, Email, Address and Phone records (including the
AdditionalContactFields custom fields), to read CustomField metadata, and to
call MessageTemplate.send.

=head2 Preference custom fields

The directory and mailing preferences are Yes/No custom fields in the
AdditionalContactFields custom group, listed by id in
L</%PREFERENCE_FIELDS>. APIv4 addresses custom fields as
C<GroupName.field_name>, so the ids are resolved to those names with one
CustomField.get call, cached for the life of the process.

If you need the site_key (I thought I might but currently don't seem to), it
shows up on the Contact's "API Key" screen.

=head2 handy links for development:

=over 4

=item api4 explorer

https://bacds.civicrm.org/civicrm/api4/rest#/explorer/

=item api4 docs

https://docs.civicrm.org/dev/en/latest/api/v4/usage/

=item api3 explorer

https://bacds.civicrm.org/civicrm/api3#explorer

=item the PHP version of what does this:

https://github.com/systopia/de.systopia.selfservice/blob/master/api/v3/Selfservice/Sendlink.php

=item permissions and access control

https://docs.civicrm.org/user/en/latest/initial-set-up/permissions-and-access-control/

=item auth

https://docs.civicrm.org/dev/en/latest/framework/authx/

=item api key

https://docs.civicrm.org/sysadmin/en/latest/setup/api-keys/

https://civicrm.org/extensions/api-key

https://civicrm.stackexchange.com/questions/9945/how-do-i-set-up-an-api-key-for-a-user

=back

=head1 METHODS

=cut

package bacds::Scheduler::CiviCRM;

use 5.32.1;
use warnings;

use Carp qw/croak/;
use Data::Dump qw/dump/;
use DateTime;
use JSON::MaybeXS qw/encode_json decode_json/;
use LWP::UserAgent;
use HTTP::Request::Common;
use URI;

our $CIVICRM_BASE_URL = 'https://bacds.civicrm.org';

use constant DEBUG => 0;

our $MOCK_API_KEY;

# The CiviCRM contribution page members use to pay for or renew a membership
our $MEMBERSHIP_PAYMENT_PAGE_ID = 2;

# How long the checksum in the payment link stays valid, in hours
use constant PAYMENT_LINK_TTL_HOURS => 1;

# Our key for each preference => CiviCRM CustomField id
# (AdditionalContactFields group), in display order.
my %PREFERENCE_FIELDS = (
    directory_include      => 3,  # Include me in membership directory?
    directory_show_email   => 4,  # Show my email address in directory?
    directory_show_phone   => 5,  # Show my phone number in directory?
    directory_show_address => 6,  # Show my street address in directory?
    mass_email_ok          => 7,  # Include me in mass emails from bacds.org
    mass_postal_ok         => 8,  # Include me in mass postal mailings
);
sub preference_field_keys { return keys %PREFERENCE_FIELDS }

sub new {
    my ($class) = @_;
    my $self = bless {}, $class;
    state $api_key     = $MOCK_API_KEY || _read_private_file('civicrm-api-key');
    state $template_id = _read_private_file('civicrm-magic-link-template-id');
    $self->{api_key}     = $api_key;
    $self->{template_id} = $template_id;
    $self->{from}        = 'noreply+bacds@notification.civimail.org';
    $self->{ua}          = LWP::UserAgent->new(timeout => 15);

    if ($ENV{CIVICRM_UA_DEBUG}) {
        $self->{ua}->add_handler("request_send",  sub { shift->dump; return });
        $self->{ua}->add_handler("response_done", sub { shift->dump; return });
    }
    return $self;
}

=head2 find_member_contacts_by_email($email)

Returns an arrayref of CiviCRM contact hashes:

    {
        contact_id => 1234,
        display_name => 'Alice Smith',
    }

(sorted ascending by id) for non-deleted, non-deceased contacts that have the
given email address AND have at least one membership record.

CiviCRM may also hold contacts who have never been members — e.g. people who
registered for an event or made a one-off payment. Those contacts are excluded
here because the member portal is specifically for reviewing and updating
membership information, and showing it to non-members would be confusing.

Returns an empty arrayref if none found.

=cut

sub find_member_contacts_by_email {
    my ($self, $email) = @_;

    my $result = $self->_call_v4('Email', 'get', {
        select  => ['contact_id', 'contact_id.display_name'],
        join    => [['Membership AS membership', 'INNER', ['contact_id', '=', 'membership.contact_id']]],
        where   => [
            ['email',                  '=', $email],
            ['contact_id.is_deleted',  '=', \0],
            ['contact_id.is_deceased', '=', \0],
        ],
        groupBy => ['contact_id'],
        orderBy => {'contact_id' => 'ASC'},
    });

    return [
        map {
            {
                contact_id   => $_->{contact_id},
                display_name => $_->{'contact_id.display_name'},
            }
        } @{ $result->{values} }
    ];
}

=head2 find_related_member_contacts_by_email($email)

Like L</find_member_contacts_by_email>, but for contacts who have no
membership of their own and are instead covered by someone else's. For
example, the spouse of a Family member when CiviCRM didn't create an
inherited membership for them (say the type's max_related was already
reached).

A contact qualifies if they have a current relationship to a contact who
directly holds a membership, and that membership's type lists the
relationship type and direction for inheritance. This is the same rule
CiviCRM uses to create inherited memberships; see
L</_owner_memberships_via_relationship>.

Returns the same shape as find_member_contacts_by_email, sorted ascending by
contact_id, or an empty arrayref.

=cut

sub find_related_member_contacts_by_email {
    my ($self, $email) = @_;

    my $result = $self->_call_v4('Email', 'get', {
        select  => ['contact_id', 'contact_id.display_name'],
        where   => [
            ['email',                  '=', $email],
            ['contact_id.is_deleted',  '=', \0],
            ['contact_id.is_deceased', '=', \0],
        ],
        groupBy => ['contact_id'],
        orderBy => {'contact_id' => 'ASC'},
    });
    my @contacts = @{ $result->{values} }
        or return [];

    my $owner_memberships = $self->_owner_memberships_via_relationship(
        [ map { $_->{contact_id} } @contacts ]
    );

    return [
        map {
            {
                contact_id   => $_->{contact_id},
                display_name => $_->{'contact_id.display_name'},
            }
        } grep { $owner_memberships->{ $_->{contact_id} } } @contacts
    ];
}

=head2 get_contact($contact_id)

Returns a hashref with the contact's name, email (read-only), primary
address, primary phone, and most recent membership. Missing fields default
to ''.

Also includes each key of %PREFERENCE_FIELDS (directory_include,
mass_email_ok, etc.) as 1 or 0; an unset field counts as 0.

The membership fields describe the latest-ending membership that covers
the contact. That's either their own (possibly inherited) membership, or one
held by a related contact (see L</find_related_member_contacts_by_email>).

If the membership is held by someone else, either as an inherited
membership or through a relationship, membership_owner_name is the holder's
display name and membership_payment_url is '', since only the holder can
renew it. Otherwise membership_owner_name is '', and membership_payment_url
links to the CiviCRM contribution page with the contact's email and
membership level pre-filled (see L</membership_payment_url>).

When the contact holds the membership themselves, membership_covers lists
the other people it covers through a relationship, as
C<< { contact_id, display_name, relationship } >> hashes (relationship is
the other person's side, e.g. "Spouse of"), and membership_max_related is
the membership type's limit on them, or undef for none. Otherwise
membership_covers is [] and membership_max_related is undef.

=cut

sub get_contact {
    my ($self, $contact_id) = @_;

    my $pref_api_name = $self->_preference_api_names;

    my $contact_result = $self->_call_v4('Contact', 'get', {
        select => [qw(
            first_name
            middle_name
            last_name
            nick_name
            email_primary.email
        ), values %$pref_api_name],
        where => [['id', '=', $contact_id]],
    });

    my $contact = $contact_result->{values}[0]
        or croak "Contact $contact_id not found in CiviCRM";

    my $addr_result = $self->_call_v4('Address', 'get', {
        select => [qw(
            id
            street_address
            city
            state_province_id:label
            postal_code
            country_id:label
        )],
        where  => [
            ['contact_id', '=', $contact_id],
            ['is_primary',  '=', \1],
        ],
        limit => 1,
    });

    my $phone_result = $self->_call_v4('Phone', 'get', {
        select => [qw(id phone)],
        where  => [
            ['contact_id', '=', $contact_id],
            ['is_primary',  '=', \1],
        ],
        limit => 1,
    });

    my $membership_result = $self->_call_v4('Membership', 'get', {
        select  => [qw(
            id
            end_date
            membership_type_id
            membership_type_id:name
            owner_membership_id
            owner_membership_id.contact_id.display_name
        )],
        where   => [['contact_id', '=', $contact_id]],
        orderBy => {'end_date' => 'DESC'},
        limit   => 1,
    });

    my @memberships;
    if (my $own = $membership_result->{values}[0]) {
        push @memberships, {
            id         => $own->{id},
            end_date   => $own->{end_date},
            type_id    => $own->{membership_type_id},
            type_name  => $own->{'membership_type_id:name'},
            owner_name => (
                $own->{owner_membership_id}
                    ? $own->{'owner_membership_id.contact_id.display_name'}
                    : ''
            ),
        };
    }
    my $related = $self->_owner_memberships_via_relationship([$contact_id]);
    push @memberships, @{ $related->{$contact_id} // [] };

    my ($membership) = sort {
        ($b->{end_date} // '') cmp ($a->{end_date} // '')
    } @memberships;
    $membership //= {};

    # If they hold it themselves, who else it covers
    my $covered = { max_related => undef, covered => [] };
    if ($membership->{id} && !$membership->{owner_name}) {
        $covered = $self->_covered_by_membership($contact_id, $membership->{type_id});
    }

    my $addr       = $addr_result->{values}[0]       // {};
    my $phone      = $phone_result->{values}[0]      // {};

    my %prefs = map {
        $_ => ($contact->{ $pref_api_name->{$_} } ? 1 : 0)
    } keys %PREFERENCE_FIELDS;

    return {
        %prefs,
        contact_id           => $contact_id,
        first_name           => $contact->{first_name} // '',
        middle_name          => $contact->{middle_name} // '',
        last_name            => $contact->{last_name} // '',
        nick_name            => $contact->{nick_name} // '',
        email                => $contact->{'email_primary.email'} // '',
        street_address       => $addr->{street_address} // '',
        city                 => $addr->{city} // '',
        state                => $addr->{'state_province_id:label'} // '',
        postal_code          => $addr->{postal_code} // '',
        country              => $addr->{'country_id:label'} // 'United States',
        phone                => $phone->{phone} // '',
        membership_id        => $membership->{id} // '',
        membership_owner_name => $membership->{owner_name} // '',
        membership_payment_url => (
            $membership->{id} && !$membership->{owner_name}
                ? $self->membership_payment_url($contact_id, $membership->{id})
                : ''
        ),
        membership_type_name => $membership->{type_name} // '',
        membership_covers    => $covered->{covered},
        membership_max_related => $covered->{max_related},
        membership_end       => $membership->{end_date} // '',
        membership_is_active => (
            $membership->{end_date}
                ? (DateTime->now->ymd le $membership->{end_date} ? 1 : 0)
                : undef
        ),
    };
}

=head2 membership_payment_url($contact_id, $membership_id)

Returns a link to the membership contribution page,
$MEMBERSHIP_PAYMENT_PAGE_ID, for this contact and membership:

    https://bacds.civicrm.org/civicrm/contribute/transact?reset=1&id=2&cid=...&mid=...&cs=...

cid and mid pre-fill the email address and pre-select the membership level.
The cs checksum lets CiviCRM accept cid without the member logging in; it
expires after PAYMENT_LINK_TTL_HOURS.

=cut

sub membership_payment_url {
    my ($self, $contact_id, $membership_id) = @_;

    my $result = $self->_call_v4('Contact', 'getChecksum', {
        contactId => $contact_id,
        ttl       => PAYMENT_LINK_TTL_HOURS,
    });
    my $checksum = $result->{values}[0]{checksum}
        or croak "CiviCRM returned no checksum for contact $contact_id";

    my $uri = URI->new("$CIVICRM_BASE_URL/civicrm/contribute/transact");
    $uri->query_form(
        reset => 1,
        id    => $MEMBERSHIP_PAYMENT_PAGE_ID,
        cid   => $contact_id,
        mid   => $membership_id,
        cs    => $checksum,
    );
    return $uri->as_string;
}

=head2 update_contact($contact_id, \%data)

Updates the contact's name fields, preference custom fields, primary
address, and primary phone in CiviCRM. Email is intentionally excluded
(read-only). Each field is only updated if its key is present in %data;
preference values are treated as booleans.

=cut

sub update_contact {
    my ($self, $contact_id, $data) = @_;

    # Update core name fields and preference custom fields
    my %contact_fields;
    for my $field (qw(first_name middle_name last_name nick_name)) {
        $contact_fields{$field} = $data->{$field} if exists $data->{$field};
    }
    if (grep { exists $data->{$_} } keys %PREFERENCE_FIELDS) {
        my $pref_api_name = $self->_preference_api_names;
        for my $key (keys %PREFERENCE_FIELDS) {
            next unless exists $data->{$key};
            $contact_fields{ $pref_api_name->{$key} } = $data->{$key} ? \1 : \0;
        }
    }
    if (%contact_fields) {
        $self->_call_v4('Contact', 'update', {
            values => \%contact_fields,
            where  => [['id', '=', $contact_id]],
        });
    }

    # Upsert primary address
    my %addr_fields;
    for my $field (qw(street_address city postal_code)) {
        $addr_fields{$field} = $data->{$field} if exists $data->{$field};
    }
    $addr_fields{'state_province_id:label'} = $data->{state}   if exists $data->{state};
    $addr_fields{'country_id:label'}         = $data->{country} if exists $data->{country};

    if (%addr_fields) {
        my $existing_addr = $self->_call_v4('Address', 'get', {
            select => ['id'],
            where  => [
                ['contact_id', '=', $contact_id],
                ['is_primary',  '=', \1],
            ],
            limit => 1,
        });

        if (my $addr = $existing_addr->{values}[0]) {
            $self->_call_v4('Address', 'update', {
                values => \%addr_fields,
                where  => [['id', '=', $addr->{id}]],
            });
        } else {
            $self->_call_v4('Address', 'create', {
                values => {
                    %addr_fields,
                    contact_id       => $contact_id,
                    is_primary       => \1,
                    location_type_id => 1,  # "Home"
                },
            });
        }
    }

    # Upsert primary phone
    if (exists $data->{phone} && $data->{phone} ne '') {
        my $existing_phone = $self->_call_v4('Phone', 'get', {
            select => ['id'],
            where  => [
                ['contact_id', '=', $contact_id],
                ['is_primary',  '=', \1],
            ],
            limit => 1,
        });

        if (my $phone = $existing_phone->{values}[0]) {
            $self->_call_v4('Phone', 'update', {
                values => { phone => $data->{phone} },
                where  => [['id', '=', $phone->{id}]],
            });
        } else {
            $self->_call_v4('Phone', 'create', {
                values => {
                    contact_id       => $contact_id,
                    phone            => $data->{phone},
                    is_primary       => \1,
                    location_type_id => 1,  # "Home"
                },
            });
        }
    }
}

=head2 send_magic_link_email($contact_id, $email, $display_name, $url)

Sends the magic link email to the contact via CiviCRM's MessageTemplate.send
(APIv3). The template (configured via civicrm-magic-link-template-id) must
contain a {$selfservice_url} Smarty variable.

The relevant code in api/v3/Selfservice/Sendlink.php from
git@github.com:systopia/de.systopia.selfservice.git is:

    $contact_id = min(array_keys($contact_ids));
    civicrm_api3('MessageTemplate', 'send', [
        'check_permissions' => 0,
        'id'                => $template_email_known,
        'to_name'           => civicrm_api3('Contact', 'getvalue', ['id' => $contact_id, 'return' => 'display_name']),
        'from'              => $config->getSetting('sender'),
        'contact_id'        => $contact_id,
        'to_email'          => trim($params['email']),
    ]);


=cut

sub send_magic_link_email {
    my ($self, $contact_id, $email, $display_name, $url) = @_;

    $self->_call_v3('MessageTemplate', 'send', {
        id         => $self->{template_id},
        contact_id => $contact_id,
        tplParams  => { selfservice_url => $url },
        to_email   => $email,
        from       => $self->{from},
        to_name    => $display_name,
        #to_name => civicrm_api3('Contact', 'getvalue', ['id' => $contact_id, 'return' => 'display_name']),
        #check_permissions => 0, ???
    });
}

# --- private helpers ---

# Returns how each membership type passes to related contacts:
#   {
#     inherits => {
#       $membership_type_id => {
#         "${relationship_type_id}_$owner_dir" => 1,  # e.g. "8_a_b"
#         $relationship_type_id                => 1,  # listed in any direction
#       },
#     },
#     max_related           => { $membership_type_id => $max_or_undef },
#     relationship_type_ids => [ all relationship type ids listed ],
#   }
# See _owner_memberships_via_relationship for what the directions mean.
sub _membership_inheritance {
    my ($self) = @_;

    my $types_result = $self->_call_v4('MembershipType', 'get', {
        select => [qw(id relationship_type_id relationship_direction max_related)],
        where  => [['relationship_type_id', 'IS NOT EMPTY']],
    });

    my (%inherits, %max_related, %rel_type_ids);
    for my $type (@{ $types_result->{values} }) {
        my @rel_type_ids = @{ $type->{relationship_type_id}   // [] };
        my @directions   = @{ $type->{relationship_direction} // [] };
        for my $i (0 .. $#rel_type_ids) {
            $inherits{ $type->{id} }{ $rel_type_ids[$i] } = 1;
            $inherits{ $type->{id} }{ "$rel_type_ids[$i]_$directions[$i]" } = 1;
            $rel_type_ids{ $rel_type_ids[$i] } = 1;
        }
        $max_related{ $type->{id} } = $type->{max_related};
    }

    return {
        inherits              => \%inherits,
        max_related           => \%max_related,
        relationship_type_ids => [ map { $_ + 0 } sort keys %rel_type_ids ],
    };
}

# True for relationship types with the same name both ways, like "Spouse
# of", which CiviCRM lets a membership pass through in either direction.
# Takes a Relationship.get row that selected relationship_type_id.name_a_b
# and relationship_type_id.name_b_a.
sub _is_either_way {
    my ($rel) = @_;
    return $rel->{'relationship_type_id.name_a_b'}
        eq $rel->{'relationship_type_id.name_b_a'};
}

# The where clause for relationships CiviCRM counts as current
sub _current_relationship_where {
    return (
        ['is_active', '=', \1],
        ['OR', [
            ['end_date', 'IS NULL'],
            ['end_date', '>=', DateTime->now->ymd],
        ]],
    );
}

# For a contact who directly holds a membership of type $membership_type_id,
# returns
#   {
#     max_related => the type's limit, or undef for none,
#     covered     => [ { contact_id, display_name, relationship }, ... ],
#   }
# where covered lists the other contacts that membership passes to through
# a current relationship, by the same rule as
# _owner_memberships_via_relationship, sorted by name. relationship
# describes each contact's side, e.g. "Spouse of" or "Child of".
sub _covered_by_membership {
    my ($self, $owner_id, $membership_type_id) = @_;

    my $inheritance = $self->_membership_inheritance;
    my $inherits    = $inheritance->{inherits}{$membership_type_id};
    my $max_related = $inheritance->{max_related}{$membership_type_id};
    return { max_related => $max_related, covered => [] }
        unless $inherits;

    my $rels_result = $self->_call_v4('Relationship', 'get', {
        select => [qw(
            contact_id_a
            contact_id_b
            contact_id_a.display_name
            contact_id_b.display_name
            contact_id_a.is_deleted
            contact_id_b.is_deleted
            relationship_type_id
            relationship_type_id.name_a_b
            relationship_type_id.name_b_a
            relationship_type_id.label_a_b
            relationship_type_id.label_b_a
        )],
        where  => [
            _current_relationship_where(),
            ['relationship_type_id', 'IN', $inheritance->{relationship_type_ids}],
            ['OR', [
                ['contact_id_a', '=', $owner_id],
                ['contact_id_b', '=', $owner_id],
            ]],
        ],
    });

    my %covered;
    for my $rel (@{ $rels_result->{values} }) {
        my $owner_is_a = $rel->{contact_id_a} == $owner_id;
        my $owner_dir  = $owner_is_a ? 'a_b' : 'b_a';
        next unless $inherits->{"$rel->{relationship_type_id}_$owner_dir"}
                 || (_is_either_way($rel) && $inherits->{ $rel->{relationship_type_id} });

        # The covered contact's side: contact_a is "label_a_b" contact_b
        my ($side, $label) = $owner_is_a ? ('b', 'label_b_a') : ('a', 'label_a_b');
        my $contact_id = $rel->{"contact_id_$side"};
        next if $contact_id == $owner_id
             || $rel->{"contact_id_$side.is_deleted"};
        push @{ $covered{$contact_id}{relationships} },
            $rel->{"relationship_type_id.$label"};
        $covered{$contact_id}{display_name} = $rel->{"contact_id_$side.display_name"};
    }

    return {
        max_related => $max_related,
        covered     => [
            map {
                {
                    contact_id   => $_,
                    display_name => $covered{$_}{display_name},
                    relationship => join(', ', @{ $covered{$_}{relationships} }),
                }
            }
            sort { lc $covered{$a}{display_name} cmp lc $covered{$b}{display_name} }
            keys %covered
        ],
    };
}

# Given an arrayref of contact ids, returns a hashref of
#   contact_id => [ { id, end_date, type_name, owner_name }, ... ]
# listing the memberships held directly (not inherited) by other contacts
# that cover each of them through a relationship. Contacts with none are
# left out.
#
# This mirrors CRM_Member_BAO_Membership::checkMembershipRelationship, the
# rule CiviCRM uses to create inherited memberships:
#  - the relationship must be current: active, and no end_date in the past
#  - the membership type must list the relationship type with the owner's
#    direction: "a_b" means the owner is contact_a, "b_a" means contact_b
#  - relationship types with the same name both ways (e.g. "Spouse of")
#    count in either direction
sub _owner_memberships_via_relationship {
    my ($self, $contact_ids) = @_;

    my $inheritance = $self->_membership_inheritance;
    my %inherits    = %{ $inheritance->{inherits} };
    my @rel_type_ids = @{ $inheritance->{relationship_type_ids} }
        or return {};

    my $rels_result = $self->_call_v4('Relationship', 'get', {
        select => [qw(
            contact_id_a
            contact_id_b
            relationship_type_id
            relationship_type_id.name_a_b
            relationship_type_id.name_b_a
        )],
        where  => [
            _current_relationship_where(),
            ['relationship_type_id', 'IN', \@rel_type_ids],
            ['OR', [
                ['contact_id_a', 'IN', $contact_ids],
                ['contact_id_b', 'IN', $contact_ids],
            ]],
        ],
    });

    # Each candidate => the other side, with the owner's direction
    my %is_candidate = map { $_ => 1 } @$contact_ids;
    my @links;
    for my $rel (@{ $rels_result->{values} }) {
        my $either_way = _is_either_way($rel);
        my @sides = (
            [ $rel->{contact_id_b}, $rel->{contact_id_a}, 'a_b' ],
            [ $rel->{contact_id_a}, $rel->{contact_id_b}, 'b_a' ],
        );
        for my $side (@sides) {
            my ($contact_id, $owner_id, $owner_dir) = @$side;
            next unless $is_candidate{$contact_id};
            push @links, {
                contact_id   => $contact_id,
                owner_id     => $owner_id,
                rel_type_dir => "$rel->{relationship_type_id}_$owner_dir",
                rel_type_any => ($either_way ? $rel->{relationship_type_id} : undef),
            };
        }
    }
    return {} unless @links;

    my $memberships_result = $self->_call_v4('Membership', 'get', {
        select => [qw(
            id
            contact_id
            end_date
            membership_type_id
            membership_type_id:name
            contact_id.display_name
        )],
        where  => [
            ['contact_id',            'IN', [ map { $_->{owner_id} } @links ]],
            ['owner_membership_id',   'IS NULL'],
            ['contact_id.is_deleted', '=',  \0],
        ],
    });
    my %memberships_by_owner;
    for my $membership (@{ $memberships_result->{values} }) {
        push @{ $memberships_by_owner{ $membership->{contact_id} } }, $membership;
    }

    my %covered;
    for my $link (@links) {
        for my $membership (@{ $memberships_by_owner{ $link->{owner_id} } // [] }) {
            my $inherits = $inherits{ $membership->{membership_type_id} }
                or next;
            next unless $inherits->{ $link->{rel_type_dir} }
                     || (defined $link->{rel_type_any}
                         && $inherits->{ $link->{rel_type_any} });
            push @{ $covered{ $link->{contact_id} } }, {
                id         => $membership->{id},
                end_date   => $membership->{end_date},
                type_name  => $membership->{'membership_type_id:name'},
                owner_name => $membership->{'contact_id.display_name'},
            };
        }
    }

    return \%covered;
}

# Returns a hashref of our preference key => APIv4 field name, e.g.
#   directory_include => 'AdditionalContactFields.Include_in_directory'
# looked up from the CustomField ids in %PREFERENCE_FIELDS. Cached for
# the life of the process.
sub _preference_api_names {
    my ($self) = @_;

    state %api_name;
    return \%api_name if %api_name;

    my $result = $self->_call_v4('CustomField', 'get', {
        select => ['id', 'name', 'data_type', 'custom_group_id:name'],
        where  => [['id', 'IN', [values %PREFERENCE_FIELDS]]],
    });
    my %field_by_id = map { $_->{id} => $_ } @{ $result->{values} };

    my %found;
    for my $key (keys %PREFERENCE_FIELDS) {
        my $id = $PREFERENCE_FIELDS{$key};
        my $field = $field_by_id{$id}
            or croak "CiviCRM custom field $id ($key) not found";
        $field->{data_type} eq 'Boolean'
            or croak "CiviCRM custom field $id ($key) is $field->{data_type}, expected Boolean";
        $found{$key} = "$field->{'custom_group_id:name'}.$field->{name}";
    }
    %api_name = %found;

    return \%api_name;
}

sub _call_v4 {
    my ($self, $entity, $action, $params) = @_;

    my $url = $CIVICRM_BASE_URL . "/civicrm/ajax/api4/$entity/$action";
    my $req = POST($url,
        'X-Civi-Auth' => 'Bearer ' . $self->{api_key},
        # tried using the site_key in response to
        # HTTP 401 Login not permitted. Must satisfy guard (site_key, perm)
        # from https://bacds.civicrm.org/civicrm/contact/view?reset=1&cid=11
        #'X-Civi-Key' => $self->{site_key},
        # but it turned out to be some different issue and site_key is unnecessary.
        Content_Type => 'application/x-www-form-urlencoded',
        # As a list so it gets URL-encoded; a raw string would turn a "+"
        # in an email address or phone number into a space.
        Content       => [ params => encode_json($params) ],

        # To ensure broad compatibility, APIv4 REST clients should set this
        # HTTP header https://docs.civicrm.org/dev/en/latest/api/v4/rest/
        'X-Requested-With' => 'XMLHttpRequest',
    );

    say STDERR 'v4 about to send: ', $req->as_string
        if DEBUG;

    return $self->_dispatch($req);
}

# MessageTemplate.send is only available in APIv3.
sub _call_v3 {
    my ($self, $entity, $action, $params) = @_;

    my $url  = $CIVICRM_BASE_URL . '/civicrm/ajax/rest';
    my $body = encode_json({ %$params });
    my $req  = POST($url,
        'X-Civi-Auth' => 'Bearer ' . $self->{api_key},
        Content_Type  => 'application/x-www-form-urlencoded',
        Content       => [
            entity => $entity,
            action => $action,
            json => $body,
        ],
    );
    say STDERR 'v3 about to send: ', $req->as_string, "\n", $body
        if DEBUG;

    return $self->_dispatch($req);
}

sub _dispatch {
    my ($self, $req) = @_;

    my $response = $self->{ua}->request($req);

    croak "CiviCRM HTTP error: " . $response->status_line . ' - ' . $response->content
        unless $response->is_success;

    my $data = eval { decode_json($response->decoded_content) };
    croak "CiviCRM returned invalid JSON: $@\n".$response->decoded_content if $@;

    if ($data->{is_error}) {
        croak "CiviCRM API error: " . ($data->{error_message} // 'unknown error');
    }
    dump '_dispatch response:', $data if DEBUG;

    return $data;
}

sub _read_private_file {
    my ($filename) = @_;

    my @candidates = (
        (defined $ENV{HOME} ? "$ENV{HOME}/.$filename" : ()),
        "/var/www/bacds.org/dance-scheduler/private/$filename",
    );

    for my $path (@candidates) {
        next unless -e $path;
        open my $fh, '<', $path or croak "can't read $path: $!";
        my $value = <$fh>;
        chomp $value;
        return $value;
    }

    croak "Can't find private file '$filename'; tried: " . join(', ', @candidates);
}

1;
