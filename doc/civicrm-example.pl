use strict;
use warnings;
use LWP::UserAgent;
use JSON;

# set this in your env for LWP::UserAgent debugging output
# CIVICRM_UA_DEBUG=1

# 1. Configuration
#my $site_url = 'https://{yoursite}/civicrm/api4/rest';
my $site_url = 'https://bacds.civicrm.org/civicrm/ajax/api4';
my $api_key  = `cat ~/.civicrm-api-key`;
#my $site_key = '...';

# 2. Define the Request Data
# This example fetches the first 5 Individual contacts
my $params = {
    'select' => ['id', 'display_name', 'email'],
    'where'  => [['contact_type', '=', 'Individual'], ['id', '=', '3']],
    'limit'  => 5,
};

# Combine entity and action for the generic REST endpoint
# Or use: https://{yoursite}/civicrm/api4/Contact/get
my $payload = {
    'entity' => 'Contact',
    'action' => 'get',
    'params' => $params,
};

# 3. Create the User Agent and Request
my $ua = LWP::UserAgent->new;
if ($ENV{CIVICRM_UA_DEBUG}) {
    $ua->add_handler("request_send",  sub { shift->dump; return });
    $ua->add_handler("response_done", sub { shift->dump; return });
}
my $req = HTTP::Request->new(POST => "$site_url/Contact/get");

# Set necessary headers
$req->header('Content-Type'     => 'application/x-www-form-urlencoded');
$req->header('X-Civi-Auth'      => "Bearer $api_key"); # Modern APIv4 auth
#$req->header('X-Civi-Site-Key' => $site_key);         # Site key often required

# Encode data as JSON
$req->content('params='.encode_json($params));
    
 

# 4. Execute and Parse Response
my $res = $ua->request($req);

if ($res->is_success) {
    my $data = decode_json($res->decoded_content);
    
    # Process the 'values' array returned by APIv4
    foreach my $contact (@{$data->{values}}) {
        print "ID: $contact->{id} | Name: $contact->{display_name}\n";
    }
} else {
    die "HTTP POST error: " . $res->status_line . "\n" . $res->decoded_content;
}

