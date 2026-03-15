=head1 NAME

bacds::Scheduler::CiviCRM - Client for the CiviCRM REST API

=head1 SYNOPSIS

    my $civi = bacds::Scheduler::CiviCRM->new;

    my $contact_ids = $civi->find_contacts_by_email('member@example.com');
    my $contact     = $civi->get_contact($contact_id);
    $civi->update_contact($contact_id, \%new_data);
    $civi->send_magic_link_email($contact_id, $url);

=head1 DESCRIPTION

Wraps CiviCRM's REST API for the member self-service portal.

Data operations use APIv4 (POST /civicrm/ajax/api4/{Entity}/{Action}).

Email sending uses APIv3 MessageTemplate.send (POST /civicrm/ajax/rest),
which is not available in APIv4.

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

=cut

package bacds::Scheduler::CiviCRM;

use 5.16.0;
use warnings;

use Carp qw/croak/;
use JSON::MaybeXS qw/encode_json decode_json/;
use LWP::UserAgent;
use HTTP::Request::Common;

use constant CIVICRM_BASE_URL => 'https://bacds.civicrm.org';

sub new {
    my ($class) = @_;
    my $self = bless {}, $class;
    $self->{api_key}     = _read_private_file('civicrm-api-key');
    $self->{template_id} = _read_private_file('civicrm-magic-link-template-id');
    $self->{ua}          = LWP::UserAgent->new(timeout => 15);
    return $self;
}

=head2 find_contacts_by_email($email)

Returns an arrayref of CiviCRM contact_ids (sorted ascending by id) for
non-deleted, non-deceased contacts that have the given email address.
Returns an empty arrayref if none found.

=cut

sub find_contacts_by_email {
    my ($self, $email) = @_;

    my $result = $self->_call_v4('Email', 'get', {
        select  => ['contact_id'],
        where   => [
            ['email',                  '=', $email],
            ['contact_id.is_deleted',  '=', \0],
            ['contact_id.is_deceased', '=', \0],
        ],
        orderBy => [['contact_id', 'ASC']],
    });

    return [map { $_->{contact_id} } @{ $result->{values} }];
}

=head2 get_contact($contact_id)

Returns a hashref with the contact's name, email (read-only), primary
address, and primary phone. Missing fields default to ''.

=cut

sub get_contact {
    my ($self, $contact_id) = @_;

    my $contact_result = $self->_call_v4('Contact', 'get', {
        select => [qw(
            first_name
            middle_name
            last_name
            nick_name
            email_primary.email
        )],
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

    my $addr  = $addr_result->{values}[0]  // {};
    my $phone = $phone_result->{values}[0] // {};

    return {
        contact_id     => $contact_id,
        first_name     => $contact->{first_name}              // '',
        middle_name    => $contact->{middle_name}             // '',
        last_name      => $contact->{last_name}               // '',
        nick_name      => $contact->{nick_name}               // '',
        email          => $contact->{'email_primary.email'}   // '',
        street_address => $addr->{street_address}             // '',
        city           => $addr->{city}                       // '',
        state          => $addr->{'state_province_id:label'}  // '',
        postal_code    => $addr->{postal_code}                // '',
        country        => $addr->{'country_id:label'}         // 'United States',
        phone          => $phone->{phone}                     // '',
    };
}

=head2 update_contact($contact_id, \%data)

Updates the contact's name fields, primary address, and primary phone in
CiviCRM. Email is intentionally excluded (read-only). Each section is only
updated if its keys are present in %data.

=cut

sub update_contact {
    my ($self, $contact_id, $data) = @_;

    # Update core name fields
    my %name_fields;
    for my $field (qw(first_name middle_name last_name nick_name)) {
        $name_fields{$field} = $data->{$field} if exists $data->{$field};
    }
    if (%name_fields) {
        $self->_call_v4('Contact', 'update', {
            values => \%name_fields,
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

=head2 send_magic_link_email($contact_id, $url)

Sends the magic link email to the contact via CiviCRM's MessageTemplate.send
(APIv3). The template (configured via civicrm-magic-link-template-id) must
contain a {$selfservice_url} Smarty variable.

=cut

sub send_magic_link_email {
    my ($self, $contact_id, $url) = @_;

    $self->_call_v3('MessageTemplate', 'send', {
        id         => $self->{template_id},
        contact_id => $contact_id,
        tplParams  => { selfservice_url => $url },
    });
}

# --- private helpers ---

sub _call_v4 {
    my ($self, $entity, $action, $params) = @_;

    my $url = CIVICRM_BASE_URL . "/civicrm/ajax/api4/$entity/$action";
    my $req = POST($url,
        'X-Civi-Auth' => 'Bearer ' . $self->{api_key},
        Content_Type  => 'application/json',
        Content       => encode_json($params),
    );

    return $self->_dispatch($req);
}

# MessageTemplate.send is only available in APIv3.
sub _call_v3 {
    my ($self, $entity, $action, $params) = @_;

    my $url  = CIVICRM_BASE_URL . '/civicrm/ajax/rest';
    my $body = encode_json({ entity => $entity, action => $action, %$params });
    my $req  = POST($url,
        'X-Civi-Auth' => 'Bearer ' . $self->{api_key},
        Content_Type  => 'application/x-www-form-urlencoded',
        Content       => [json => $body],
    );

    return $self->_dispatch($req);
}

sub _dispatch {
    my ($self, $req) = @_;

    my $response = $self->{ua}->request($req);

    croak "CiviCRM HTTP error: " . $response->status_line
        unless $response->is_success;

    my $data = eval { decode_json($response->decoded_content) };
    croak "CiviCRM returned invalid JSON: $@" if $@;

    if ($data->{is_error}) {
        croak "CiviCRM API error: " . ($data->{error_message} // 'unknown error');
    }

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
