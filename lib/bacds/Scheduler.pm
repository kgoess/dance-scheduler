=head1 NAME

bacds::Scheduler - web controller for the BACDS Dance Scheduler single page app

=head1 SYNOPSIS

In dancer's config.yml:

    appname: "bacds::Scheduler"

=head1 DESCRIPTION

These are the url endpoints for the app.

=head1 ENDPOINTS

=cut

package bacds::Scheduler;

use 5.16.0;
use warnings;

use Dancer2;
use Dancer2::Core::Cookie;
use Dancer2::Plugin::HTTP::ContentNegotiation;
use Dancer2::Plugin::ParamTypes;
use Data::Dump qw/dump/;
use Hash::MultiValue;
use List::Util; # "any" is exported by Dancer2 qw/any/;
use HTML::Entities qw/decode_entities/;
use Scalar::Util qw/looks_like_number/;
use Time::Piece;
use WWW::Form::UrlEncoded qw/parse_urlencoded_arrayref/;
use YAML qw/Load/;

use bacds::Scheduler::Auditor;
use bacds::Scheduler::FederatedAuth;
use bacds::Scheduler::Plugin::AccordionConfig;
use bacds::Scheduler::Plugin::Auth;
use bacds::Scheduler::Plugin::Checksum;
use bacds::Scheduler::Model::Band;
use bacds::Scheduler::Model::Caller;
use bacds::Scheduler::Model::DanceFinder;
use bacds::Scheduler::Model::Event;
use bacds::Scheduler::Model::ParentOrg;
use bacds::Scheduler::Model::Programmer;
use bacds::Scheduler::Model::Series;
use bacds::Scheduler::Model::SeriesLister;
use bacds::Scheduler::Model::Talent;
use bacds::Scheduler::Model::Style;
use bacds::Scheduler::Model::Venue;
use bacds::Scheduler::Util::Cookie qw/LoginMethod LoginSession GoogleToken/;
use bacds::Scheduler::Util::Db qw/get_dbh/;
use bacds::Scheduler::Util::Results;
my $Results_Class = "bacds::Scheduler::Util::Results";

our $VERSION = '0.1';

register_type_check 'SchedulerId' => sub {
    return 1 unless $_[0]; # the form can send ""
    return unless looks_like_number( $_[0] );
    return unless $_[0] >= 0;
    return unless $_[0] <= 2147483647; # mysql INT
    return 1;
};
register_type_check 'Timestamp' => sub {
    return unless looks_like_number( $_[0] );
    return unless $_[0] >= 0;
    return 1;
};
# usable for series.series_xid or venue.vkey
register_type_check 'XID' => sub {
    return $_[0] =~ /^[A-Z0-9._-]{3,32}$/;
};

preload_accordion_config;


=head2 before hook

The "before" hook is set up to catch every dancer2 request, check for the
LoginMethod cookie and associated login cookie, and if they check out then put
the "signed_in_as" programmer in the var() stash. It also creates an bacds::Scheduler::Auditor in the var() stash under "auditor".

See bacds::Scheduler::FederatedAuth for what sets these cookies.

We might not need this for static assets like images or css. Could screen
on the Accept header, Content Negotiation.

=cut

hook before => sub {
    my $login_cookie = cookie LoginMethod
        or return;

    my $login_method = $login_cookie->value;

    my $signed_in_as;

    given ($login_method) {
        when ('google') {
            my $google_token = cookie GoogleToken
                or return;
            my ($programmer, $err) = bacds::Scheduler::FederatedAuth
                ->check_google_auth($google_token);
            if ($err) {
                my ($code, $msg) = @$err;
                warn qq{hook before check_google_auth: "$msg" for token '$google_token"};
                return;
            }
            $signed_in_as = $programmer;
        }
        when ('session') {
            # this handles both facebook and bacds signins
            my $session_cookie = cookie LoginSession
                or return;

            my ($programmer, $err) = bacds::Scheduler::FederatedAuth
                ->check_session_cookie($session_cookie);

            if ($err) {
                warn qq{hook before session: "$err" for $session_cookie};
                return;
            };

            $signed_in_as = $programmer;
        }
    }
    if ($signed_in_as) {
        var signed_in_as => $signed_in_as;
        var auditor => bacds::Scheduler::Auditor->new(
            programmer => $signed_in_as,
            http_method => request->method,
        );
    }
};

=head2 /google-signin

login credential checking redirector

A request to https://www.bacds.org/dance-scheduler/signin.html
will show a login-with-google button and others.

Click on that and you'll get a "Sign in with Google: Choose
an account to continue to bacds.org" page.

Continuing with that will redirect you here.

This endpoint will verify your credential information and set up a
session.

See also bacds::Scheduler::FederatedAuth->check_google_auth.

=cut

post '/google-signin' => sub {
    my $jwt = params->{credential}
        or send_error 'missing parameter "credential"' => 400;

    my ($res, $err) = bacds::Scheduler::FederatedAuth->check_google_auth($jwt);

    if ($err) {
        my ($code, $msg) = @$err;
        send_error $msg => $code;
    }

    cookie GoogleToken, $jwt,     expires => "72 hours";
    cookie LoginMethod, 'google', expires => "72 hours";
    redirect '/' => 303;
};

=head2 /facebook-signin

login credential checking redirector

A request to https://www.bacds.org/dance-scheduler/signin.html
will show a login-with-facebook button and others.

Click on that facebook button and after logging in to facebok it'll redirect
you here.

This endpoint will verify your credential information and set up a
session.

See also bacds::Scheduler::FederatedAuth->check_facebook_auth

=cut

post '/facebook-signin' => sub {
    my $access_token = params->{access_token}
        or send_error 'missing parameter "access_token"' => 400;

    my ($programmer, $err) = bacds::Scheduler::FederatedAuth
        ->check_facebook_auth($access_token);

    if ($err) {
        my ($code, $msg) = @$err;
        send_error $msg => $code;
    }

    my $email = $programmer->email;

    # Checking the facebook cookie requires making an HTTP request to facebook
    # every time, so instead of doing that, we'll use our own session cookie.
    # We should just do this with Google too, and then we can probably just use
    # the Plack auth session.
    my $session_cookie = bacds::Scheduler::FederatedAuth->create_session_cookie($email);
    cookie LoginSession, $session_cookie, expires => "72 hours";
    cookie LoginMethod, 'session';
    redirect '/' => 303;
};

=head2 /bacds-signin

login credential checking redirector

A request to signin.html will show a login-with-bacds button
and others. Submitting the bacds login form ends up here.

=cut

post '/bacds-signin' => sub {
    my $programmer_email = params->{programmer_email}
        or send_error 'missing parameter "programmer_email"' => 400;
    my $password = params->{password}
        or send_error 'missing parameter "password"' => 400;

    my ($email, $err) = bacds::Scheduler::FederatedAuth->check_bacds_auth($programmer_email, $password);

    if ($err) {
        my ($code, $msg) = @$err;
        warn "login failure for $programmer_email: $msg\n";
        send_error $msg => $code;
    }

    my $session_cookie = bacds::Scheduler::FederatedAuth->create_session_cookie($email);

    cookie LoginSession, $session_cookie, expires => "72 hours";
    cookie LoginMethod, 'session'       , expires => "72 hours";
    redirect '/' => 303;
};

=head2 /signout

=cut

get '/signout' => sub {
    cookie LoginSession, '', expires => "-1 hours";
    cookie LoginMethod,  '', expires => "-1 hours";
    redirect '/signin.html', 302;
};


=head2 login page

The page that asks you to log in with google/facebook/custom pass

See also the dancer2 docs about logins etc:
https://metacpan.org/dist/Dancer2/view/lib/Dancer2/Manual.pod#Sessions-and-logging-in

=cut

get '/login' => sub {
    template login => {
        title => 'Dance Schedule Login',
    },
    {layout => undef},
};

=head2 main/root

The display page. This is the only endpoint that serves html.

=cut

get '/' => requires_login sub {

    # see accordions-webui.yml
    my $accordion = get_accordion_config();

    my $checksum = bacds::Scheduler::Util::Initialize::get_checksum();
    cookie Checksum => $checksum;

    template 'accordion' => {
        checksum => $checksum,
        title => 'Dance Scheduler',
        signed_in_as => vars->{signed_in_as}->email,
        test_db_name => bacds::Scheduler::Util::Db->using_test_db,
        accordion => $accordion,
    };
};



=head2 Events

=head3 GET /eventAll

Returns the flat list of all events in the database

    "data": [
      {
        "event_id": 44,
        "name": "2022-06-08 ENGLISH CCB Sharon Green",
        "is_camp": 1,
        "is_deleted": 0,
        "short_desc": "Sharon Green",
        "long_desc": "Sharon Green with out-of-town special guests...",
        "start_date": "2022-06-08",
        "start_time": "00:00:00",
        ...
      },
      ...
    "errors": []



=cut

my $event_model = 'bacds::Scheduler::Model::Event';

get '/eventAll' => requires_checksum sub {
    my $results = $Results_Class->new;

    $results->data($event_model->get_multiple_rows);

    return $results->format;
};

=head3 GET /eventsUpcoming

Like /eventAll, but just events from yesterday on.

=cut

get '/eventsUpcoming' => requires_checksum sub {
    my $results = $Results_Class->new;

    $results->data($event_model->get_upcoming_rows);

    return $results->format;
};

=head3 GET /event/:event_id

Returns the complete set of data for the event, including all
the nested data structures.

    "data": {
      "event_id": 45,
      "name": "2022-06-22 ENGLISH CCB Bruce Hamilton",
      "start_date": "2022-06-08",
      "start_time": "00:00:00",
      "short_desc": "Bruce Hamilton",
      "long_desc": "Bruce Hamilton with Craig Johnson, Judy Linsenberg...",
      "venues": [ {
          "name": "CCB",
          "id": 13
        }
      ],
      "styles": [ {
          "id": 5,
          "name": "ENGLISH"
        }
      ],
      "series": [ {
          "name": "Berkeley Wednesday English",
          "id": 21
        }
      ]
      ...
    },
    "errors": []

=cut

get '/event/:event_id' => requires_checksum sub {
    my $event_id = params->{event_id};
    my ($event, $err) = $event_model->get_row($event_id);

    return $err->format if $err;

    my $results = $Results_Class->new;
    $results->data($event);
    return $results->format;
};


=head3 POST /event/

Create a new event.

=cut

post '/event/' => can_create_event requires_checksum sub {
    my $auditor = request->var('auditor');

    my ($event, $err) = $event_model->post_row($auditor, params);

    return $err->format if $err;

    $auditor->save;

    my $results = $Results_Class->new;
    $results->data($event);
    return $results->format;
};


=head3 PUT /event/:event_id

Update an existing event

=cut

put '/event/:event_id' => requires_checksum can_edit_event sub {
    my $auditor = request->var('auditor');

    my ($event, $err) = $event_model->put_row($auditor, params);

    return $err->format if $err;

    $auditor->save;

    my $results = $Results_Class->new;
    $results->data($event);
    return $results->format;
};


=head2 Boilerplate getters/setters

These are all described in the YAML in the code below:

=head2 Styles

=head3 GET /styleAll

Returns all of the styles in the db not marked "is_deleted".

    "data": [
      {
        "name": "CONTRA",
        "style_id": 6
      },
      {
        "name": "ENGLISH",
        "style_id": 5
      },
      ...
    "errors": [],

=head3 GET /style/:style_id

=head3 POST /style/

=head3 PUT /style/:style_id

=head2 Venues

e.g. CCB Christ Church Berkeley

=head3 GET '/venue/:venue_id'

=head3 POST /venue/

=head3 PUT /venue/:venue_id

=head3 GET /venueAll

Return all the non-deleted venues

    "data": [
      {
        "venue_id": 1,
        "vkey": "ACC",
        "hall_name": "Arlington Community Church",
        "comment": "\n",
        "address": "52 Arlington Avenue",
        "city": "Kensington",
        "zip": "",
        ...
      },
     ....
    "errors": [],

=head2 Series

e.g. "Second Saturday English"

=head3 GET '/series/:series_id'

=head3 POST /series/

=head3 PUT /series/:series_id

=head3 GET /seriesAll

Return all the non-deleted seriess

=head2 Bands

=head3 GET '/band/:band_id'

=head3 POST /band/

=head3 PUT /band/:band_id

=head3 GET /bandAll

Return all the non-deleted bands

=head2 Talent

Ok, "Talent" is really just Musos, since Callers have their own class
and we don't track SoundTechs.

=head3 GET '/talent/:talent_id'

=head3 POST /talent/

=head3 PUT /talent/:talent_id

=head3 GET /talentAll

Return all the non-deleted talents

=head2 Callers

=head3 GET /callerAll

Returns all of the callers in the db not marked "is_deleted".

    "data": [
      {
        "name": "Alice Smith",
        "caller_id": 6
      },
      {
        "name": "Bob Jones",
        "caller_id": 5
      },
      ...
    "errors": [],

=head3 GET /caller/:caller_id

=head3 POST /caller

=head3 PUT /caller/:caller_id

=head2 ParentOrgs

Usually the BACDS, but we want the option to track dances for NBCDS, or Santa
Cruz, or...

=head3 GET /parentOrgsAll

Returns all of the parent orgs in the db not marked "is_deleted".

    "data": [
      {
        "full_name": "Bay Area Country Dance Society",
        "abbreviation": "BACDS",
        "parent_org_id": 6
      },
      {
        "full_name": "North Bay Country Dance Society",
        "abbreviation": "NBCDS",
        "parent_org_id": 5
      },
      ...
    "errors": [],

=head3 GET /parent_org/:parent_org_id

=head3 POST /parent_org

=head3 PUT /parent_org/:parent_org_id

=head2 Programmers

The people that are allowed to make changes

=head3 GET /ProgrammerAll

Returns all of the programmers in the db not marked "is_deleted".

=head3 GET /programmer/:programmer_id

=head3 POST /programmer

=head3 PUT /programmer/:programmer_id

=cut

my $routes_yaml = <<EOL;
- model: style
  write_perm: requires_superuser

- model: venue
  write_perm: requires_superuser

- model: series
  write_perm: requires_superuser

- model: band
  write_perm: requires_login

- model: talent
  write_perm: requires_login

- model: caller
  write_perm: requires_login

- model: parent_org
  write_perm: requires_superuser

- model: programmer
  read_perm: requires_login
  write_perm: requires_superuser

EOL

my $routes = Load($routes_yaml);

# This all looks more complicated and indirect at first glance than it
# actually is. Check out the explicit code for Events above for what
# it actually unspools to.
foreach my $r (@$routes) {

    my $pk_name = "$r->{model}_id";
    my $class_name = 'bacds::Scheduler::Model::'.camelize($r->{model});

    my $read_perm_name = $r->{read_perm} || 'requires_nothing';
    my $read_perm = \&$read_perm_name;
    my $write_perm = \&{$r->{write_perm}};

    #
    # GET /thing/1234
    #
    get "/$r->{model}/:$pk_name" => requires_checksum $read_perm->(sub {
        my $pk = params->{$pk_name};


        my ($obj, $err) = $class_name->get_row($pk);

        return $err->format if $err;

        my $results = $Results_Class->new;
        $results->data($obj);
        return $results->format;
    });

    #
    # POST /thing - add a new thing
    #
    post "/$r->{model}/" => requires_checksum $write_perm->(sub {
        my $auditor = var 'auditor';

        my ($obj, $err) = $class_name->post_row($auditor, params);

        return $err->format if $err;

        my $results = $Results_Class->new;
        $results->data($obj);
        $auditor->save;
        return $results->format;
    });


    #
    # PUT /thing/1234 - update an existing thing
    #
    put "/$r->{model}/:$pk_name" => requires_checksum $write_perm->(sub {
        my $auditor = request->var('auditor');

        my ($obj, $err) = $class_name->put_row($auditor, params);

        return $err->format if $err;

        $auditor->save;

        my $results = $Results_Class->new;
        $results->data($obj);
        return $results->format;
    });

    #
    # get /thingALL - retrieves all not-deleted of the thing
    #
    get "/$r->{model}All" => requires_checksum $read_perm->(sub {
        my $results = $Results_Class->new;

        $results->data($class_name->get_multiple_rows);

        return $results->format;
    });
}

# parent_org -> ParentOrg
sub camelize { join '', map { ucfirst lc } split /_/, shift }


=head2 GET '/series/:series_id/series-defaults-event'

This is the set of defaults for new events in the series.

=cut

get '/series/:series_id/series-defaults-event' => sub {
    my $series_id = params->{series_id};
    my $results = $Results_Class->new;

    my $event = bacds::Scheduler::Model::Series
        ->get_series_defaults_event($series_id);

    #This can be empty, indicating that there isn't a defaults set for this
    #series_id
    if ($event) {
        $results->data($event);
    }
    else {
        $results->data({
            series => [{id => $series_id}],
            is_series_defaults => 1,
        });
    }

    return $results->format;
};


=head2 Other routes, non-getter/setter ones

=head2 GET /betatest-cookie

The DBIX_TEST=1 cookie lets you see the pages as produced by this new system.

=cut

get '/betatest-cookie' => sub {

    my $curr_val = cookie 'DBIX_TEST';
    template 'betatest-cookie' => {
        curr_val => $curr_val,
    },
    {layout => undef},
};

post '/betatest-cookie' => sub {

    my $new_val = body_parameters->get('beta-cookie');
    if (!defined $new_val || !length $new_val) {
        die "missing beta-cookie parameter in form submit";
    }
    if ($new_val eq 'on') {
        cookie DBIX_TEST => 1,  domain => 'bacds.org', expires => '6 months';
    } else {
        cookie DBIX_TEST => 0,  domain => 'bacds.org', expires => '-1 day';
    }
    redirect '/betatest-cookie' => 303;
};

=head2 GET /dancefinder

Replacing the old dancefinder cgi, display the form

=cut

get '/dancefinder' => sub {

    my $data = bacds::Scheduler::Model::DanceFinder
        ->related_entities_for_upcoming_events();

    my (@callers, @venues, @bands, @musos, @styles);

    # set up the callers
    foreach my $caller_id (keys $data->{callers}) {
        my $caller = $data->{callers}{$caller_id};
        push @callers, [$caller_id, $caller->name];
    }
    @callers = sort { $a->[1] cmp $b->[1] } @callers;

    # set up the venues
    foreach my $venue_id (keys $data->{venues}) {
        my $venue = $data->{venues}{$venue_id};
        my $venue_str = $venue->city . ' -- ' .$venue->hall_name;
        push @venues, [$venue_id, $venue_str];
    }
    @venues = sort { $a->[1] cmp $b->[1] } @venues;

    # set up the bands
    foreach my $band_id (keys $data->{bands}) {
        my $band = $data->{bands}{$band_id};
        push @bands, [$band_id, $band->name];
    }
    @bands = sort { $a->[1] cmp $b->[1] } @bands;

    # set up the musos
    foreach my $muso_id (keys $data->{musos}) {
        my $muso = $data->{musos}{$muso_id};
        push @musos, [$muso_id, $muso->name];
    }
    @musos = sort { $a->[1] cmp $b->[1] } @musos;

    # set up the styles
    foreach my $style_id (keys $data->{styles}) {
        my $style = $data->{styles}{$style_id};
        push @styles, [$style_id, $style->name];
    }
    @styles = sort { $a->[1] cmp $b->[1] } @styles;

    template 'dancefinder/index.html' => {
        bacds_uri_base => 'https://www.bacds.org/',
        title => 'Find A Dance Near You!',
        callers => \@callers,
        venues  => \@venues,
        bands   => \@bands,
        musos   => \@musos,
        styles  => \@styles,
        virtual_include => {
            copyright => _virtual_include('/shared/copyright.html'),
            carousel  => _virtual_include('/shared/cd-carousel.html'),
            menu      => _virtual_include('/shared/menu.html'),
            meta_tags => _virtual_include('/shared/meta-tags.html'),
            navbar    => _virtual_include('/shared/navbar.html'),
        },

    },
    # get the wrapper from views/layouts/<whatever>
    { layout => 'dancefinder' },

};

=head2 GET /dancefinder-results

Replacing the old dancefinder cgi, display the results

=cut

get '/dancefinder-results' => with_types [
    'optional' => ['query', 'caller', 'SchedulerId'],
    'optional' => ['query', 'venue',  'SchedulerId'],
    'optional' => ['query', 'band',   'SchedulerId'],
    'optional' => ['query', 'muso',   'SchedulerId'],
    'optional' => ['query', 'style',  'SchedulerId'],
] => sub {

    my %params = (
        caller => [grep $_, query_parameters->get_all('caller')],
        venue  => [grep $_, query_parameters->get_all('venue')],
        band   => [grep $_, query_parameters->get_all('band')],
        muso   => [grep $_, query_parameters->get_all('muso')],
        style  => [grep $_, query_parameters->get_all('style')],
    );

    my $rs = bacds::Scheduler::Model::DanceFinder->search_events(
        %params
    );

    # using ->all here because the order_by generates this warning:
    #     DBIx::Class::ResultSet::_construct_results(): Unable to properly collapse
    #     has_many results in iterator mode due to order criteria - performed an
    #     eager cursor slurp underneath. Consider using ->all() instead at
    my @events = $rs->all;


    # individually look up the query parameters so we can fill them out on the
    # results page
    my $dbh = get_dbh(debug => 0);

    my @fetchers = (
        [qw/caller Caller caller_id/],
        [qw/style Style style_id/],
        [qw/venue Venue venue_id/],
        [qw/band Band band_id/],
        [qw/muso Talent talent_id /],
    );
    my %results;
    foreach my $fetcher (@fetchers) {
        my ($key, $model_name, $primary_key_name) = @$fetcher;

        my @rs;
        if (@{$params{$key}}) {
            @rs = $dbh->resultset($model_name)->search({
                is_deleted => 0,
                $primary_key_name => $params{$key},
            })->all;
        }
        $results{$key} = \@rs;
    }

    template 'dancefinder/results.html' => {
        bacds_uri_base => 'https://www.bacds.org',
        title => 'Results from dancefinder query',
        caller_arg => $results{caller},
        venue_arg  => $results{venue},
        bands_and_musos_arg  => [ @{$results{band}}, @{$results{muso}} ],
        style_arg  => $results{style},

        events => \@events,
        highlight_special_types => 1,
        virtual_include => {
            meta_tags => _virtual_include('/shared/meta-tags.html'),
            navbar    => _virtual_include('/shared/navbar.html'),
            menu      => _virtual_include('/shared/menu.html'),
            copyright => _virtual_include('/shared/copyright.html'),
        },

    },
    # no wrapper
    { layout => undef },

};

# a quick substitution for these "include virtual" directives in the original
# dancefinder html files:
# <!--#include virtual="/shared/meta-tags.html" -->
sub _virtual_include {
    my ($path) = @_;
    my $docroot = "/var/www/bacds.org/public_html";
    $path =~ s/\.\.//g; # prevent shenanigans
    my $fullpath = "$docroot/$path";
    open my $fh, "<", $fullpath or do {
        warn "can't read $fullpath $!";
        return '';
    };
    return join '', <$fh>;
}


=head2 GET livecalendar-results

This is used by the interactive calendar at https://bacds.org/livecalendar.html
which runs https://fullcalendar.io/ and sends AJAX requests to this endpoint,
expecting json in return.

We're using https://github.com/ynjia/fullcalendar-1.6.4/tree/master/demos from 2013

=cut

get '/livecalendar-results' => with_types [
    ['query', 'start', 'Timestamp'],
    ['query', 'end', 'Timestamp'],
] => sub {
    my $start = query_parameters->{start};
    my $end   = query_parameters->{end};
    my $start_date = DateTime->from_epoch(epoch => $start)->ymd;
    my $end_date   = DateTime->from_epoch(epoch => $end  )->ymd;

    my $rs = bacds::Scheduler::Model::DanceFinder->search_events(
        start_date => $start_date,
        end_date   => $end_date,
    );

    my $ret = [];

    foreach my $event ($rs->all) {
        my $titlestring = join '',
            (join '/', map $_->name, $event->styles->all),
            ' ',
            ($event->name//''), # mostly empty except for specials, camps
            ' at ',
            (join ', and ', map $_->hall_name.' in '.$_->city, $event->venues->all),
            '.';
        if ($event->callers != 0) {
            $titlestring .= ' Led by ';
            $titlestring .= join ' and ', map $_->name, $event->callers->all;
            $titlestring .= '.';
        }
        if ($event->bands != 0 || $event->talent != 0) {
            $titlestring .= ' Music by ';
            $titlestring .= join ', ', map $_->name, $event->bands->all;
            if ($event->bands != 0) {
                $titlestring .= ': ';
            }
            $titlestring .= join ', ', map $_->name, $event->talent->all;
            $titlestring .= '.';
            if ($event->and_friends) {
                $titlestring .= '&#8230;and friends ';
            }
        }

        $titlestring .= ' '.ucfirst $event->short_desc
            if $event->short_desc;

        # fullcalendar doesn't support html in the text so remove the tags
        $titlestring =~ s/<[^>]*>//g;
        $titlestring = decode_entities($titlestring);

        my $colors;
        if (my @styles = $event->styles->all) {
            $colors = _colors_for_livecalendar(map $_->name, @styles);
        } else {
            $colors = _colors_for_livecalendar('DEFAULT');
        }

        my $url = '';
        if ($url = $event->custom_url) {
            ; # done
        } elsif (my $series = $event->series) {
            $url = $series->series_url;
        }

        push $ret, {
            id => $event->event_id, # in dancefinder.pl this is just $i++
            url => $url,
            start => $event->start_date ? $event->start_date->ymd : '',
            end => $event->end_date ? $event->end_date->ymd : '',
            title => $titlestring,
            allDay => true,
            backgroundColor => $colors->{bgcolor},
            borderColor => $colors->{bordercolor},
            textColor => $colors->{textcolor},
        },
    }
    # what about this in dancefinder.pl?
    # print "$jsonobject [ ";
    send_as JSON => $ret,
        { content_type => 'application/json; charset=UTF-8' };
};

state $livecalendar_colors = {
    SPECIAL => { # and CAMP and WORKSHOP, see below
        bgcolor => 'plum',
        bordercolor => 'dimgrey',
        textcolor => 'black',
    },
    ENGLISH => {
        bgcolor => 'darkturquoise',
        bordercolor => 'darkblue',
        textcolor => 'black',
    },
    CONTRA => {
        bgcolor => 'coral',
        bordercolor => 'bisque',
        textcolor => 'black',
    },
    WOODSHED => {
      bgcolor => 'burlywood',
      bordercolor => 'sienna',
      textcolor => 'black',
    },
    DEFAULT => {
        bgcolor => 'yellow',
        bordercolor => 'antiquewhite',
        textcolor => 'black',
    },
};
$livecalendar_colors->{CAMP}     = $livecalendar_colors->{SPECIAL};
$livecalendar_colors->{WORKSHOP} = $livecalendar_colors->{SPECIAL};
# REGENCY = ENGLISH
$livecalendar_colors->{REGENCY} = $livecalendar_colors->{ENGLISH};

sub _colors_for_livecalendar {
    my (@style_names) = @_;

    @style_names or return $livecalendar_colors->{DEFAULT};

    if (@style_names == 1) {
        return $livecalendar_colors->{$style_names[0]} ||
                $livecalendar_colors->{DEFAULT};
    }

    # SPECIAL/CAMP/WORKSHOP
    if (List::Util::any {/^(?: SPECIAL | CAMP | WORKSHOP )$/x} @style_names) {
        return $livecalendar_colors->{SPECIAL};
    }

    # pick the most interesting one
    my @interesting_styles = grep { $_ !~ /^(?: ENGLISH | CONTRA )$/x } @style_names;
    if (@interesting_styles) {
        my $style = shift @interesting_styles;
        return $livecalendar_colors->{$style}
            if $livecalendar_colors->{$style};
    }

    # otherwise just pick the first one
    my $style = shift @style_names;
    return $livecalendar_colors->{$style} || $livecalendar_colors->{DEFAULT};
}


=head2 GET /serieslister

While we're beta-testing, the httpd.conf has this set:

    SetEnvIf Cookie "DBIX_TEST=1" is_preview_test

and the index.html pages will have this SSI:

    <!--#if expr='v("is_preview_test") = "1"' -->
    <!--#include virtual="/dance-scheduler/serieslister?series_xid=BERK-CONTRA"-->
    <!--#else -->
    <!--#include file="content.html" -->
    <!--#endif -->

/serieslister will show either one of:

    a) the list of upcoming dances for the series
    b) the details of the one particular dance the user clicked on

In the first case, we're the google events single-event version of the page, so
we also add the json-ld

This is a replacement for the old serieslists.pl

=cut

get '/serieslister' => with_types [
    'optional' => ['query', 'series_id', 'SchedulerId'],
    'optional' => ['query', 'series_xid', 'XID'],
    'optional' => ['query', 'event_id', 'SchedulerId'],
] => \&_details_for_series;

=head2 GET /series-page

This is the replacement for the old series-pages with their virtual includes
that called series-lister. It displays the entire page.


=cut


get '/series-page' => with_types [
    'optional' => ['query', 'series_id', 'SchedulerId'],
    'optional' => ['query', 'series_xid', 'XID'],
    'optional' => ['query', 'event_id', 'SchedulerId'],
] => \&_details_for_series;

sub _details_for_series {
    my $event_id;
    if (my $document_q = document_args()) {
        $event_id = $document_q->get('event_id')
    }
    $event_id ||= query_parameters->get('event_id'); # might still be empty

    my ($data);

    my $c = 'bacds::Scheduler::Model::SeriesLister';

    if ($event_id) {
        $data = $c->get_event_details(event_id => $event_id);
    } else {
        $data = $c->get_upcoming_events_for_series(
            series_id => query_parameters->get('series_id')//'',
            series_xid => query_parameters->get('series_xid')//'',
        );
    }

    my $series = $data->{series};

    if (my $sidebar = $series->sidebar) {
        $sidebar =~ s{<!--#include virtual="(.+?)" -->}
                     {_virtual_include($1)}eg;
        $data->{sidebar} = $sidebar;
    }
    if (my $display_text = $series->display_text) {
        $display_text =~ s{<!--#include virtual="(.+?)" -->}
                          {_virtual_include($1)}eg;
        $data->{display_text} = $display_text;
    }

    $data->{ssi_uri_for} = \&ssi_uri_for;

    if ($series->series_url =~ m{ /series/ (?<style>.+?) / (?<series_path>.+) / }x) {
        $data->{breadcrumbs} = [
            # these hrefs aren't relocalizable, e.g. for dev port :5000--maybe change
            # to uri_for if we break "/series/" into a separate app
            { label => 'series',        href => 'https://bacds.org/series/' },
            { label => $+{style},       href => "https://bacds.org/series/$+{style}" },
            { label => $+{series_path}, href => $series->series_url  },
            $event_id
                ? { label => $data->{events}[0]->start_date->strftime("%b. %e"),
                    href => $series->series_url."?event_id=$event_id" }
                : (),
        ];
    }
    

    my $template = request->path() eq '/serieslister'
        ? 'serieslister/upcoming-events'
        : 'series-page';

    $data->{mark_as_beta} = request->path() eq '/series-page';

    $data->{event_content_title} = $event_id
        ? 'This Dance'
        : 'Upcoming Events';

    $data->{season} = get_season();

    template($template, $data,
        {layout => undef},
    );
};

sub get_season {

    state $season = {
        January   => 'winter',
        February  => 'winter',
        March     => 'winter',

        April     => 'spring',
        May       => 'spring',
        June      => 'spring',

        July      => 'summer',
        August    => 'summer',
        September => 'summer',

        October   => 'fall',
        November  => 'fall',
        Decenber  => 'fall',
    };

    # see Time::Piece for this localtime() usage
    return $season->{localtime->fullmonth};
}    


=head2 Helper Methods

Not routes.

=head3 document_args

For a virtual include that leads to the dance-scheduler, if we want
to get the *original* query-string args, we need to get them from
this:

    In addition to the variables in the standard CGI environment,
    these are available...to any program invoked by the document:

    DOCUMENT_ARGS
    This variable contains the query string of the active SSI
    document, or the empty string if a query string is not included.
    For subrequests invoked through the include SSI directive,
    QUERY_STRING will represent the query string of the subrequest
    and DOCUMENT_ARGS will represent the query string of the SSI
    document.
    https://httpd.apache.org/docs/2.4/mod/mod_include.html

Ok, sure, but observation shows this is what we actually get in Dancer2:
for a request to https://bacds.org/series/contra/palo_alto/?foo=bar

  "DOCUMENT_NAME"           => "index.html",
  "DOCUMENT_ROOT"           => "/var/www/bacds.org/public_html",
  "DOCUMENT_URI"            => "/series/contra/palo_alto/index.html",
  "QUERY_STRING"            => "series_xid=PA-CONTRA",
  "QUERY_STRING_UNESCAPED"  => "foo=bar",
  "REQUEST_URI"             => "/series/contra/palo_alto/?foo=bar",

=cut

sub document_args {

    my $document_args = request->env->{QUERY_STRING_UNESCAPED}
        or return;

    # borrowed all this from Dancer2::Core::Request
    # and thence Plack::Request

    return Hash::MultiValue->new(
        @{parse_urlencoded_arrayref($document_args)}
    );
}

=head3 ssi_uri_for

If running through a virtual include, uses the original request
path from REQUEST_URI (see notes in document_args()), otherwise
uses the application path.

=cut

sub ssi_uri_for {
    shift if $_[0] eq __PACKAGE__;
    my ($params) = @_;

    my ($path) = request->env->{REQUEST_URI} =~ s/\?.*//r;

    # borrowing this from Dancer2::Core::Request->_common_uri
    my $port   = request->env->{SERVER_PORT};
    my $server = request->env->{SERVER_NAME};
    my $host   = request->host;
    my $scheme = request->scheme;

    my $uri = URI->new;
    $uri->scheme($scheme);
    $uri->authority( $host || "$server:$port" );
    $uri->path( $path      || '/' );

    $uri->query_form($params) if $params;

    # extra ${} from Dancer2's uri_for, w/ever
    return ${ $uri->canonical };
}

true;
