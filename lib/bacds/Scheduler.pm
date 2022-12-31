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
use WWW::Form::UrlEncoded qw/parse_urlencoded_arrayref/;


use bacds::Scheduler::FederatedAuth;
use bacds::Scheduler::Plugin::Auth;
use bacds::Scheduler::Model::Caller;
use bacds::Scheduler::Model::DanceFinder;
use bacds::Scheduler::Model::Event;
use bacds::Scheduler::Model::ParentOrg;
use bacds::Scheduler::Model::Programmer;
use bacds::Scheduler::Model::SeriesLister;
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

=head2 before hook

The "before" hook is set up to catch every dancer2 request, check for the
LoginMethod cookie and associated login cookie, and if they check out then put
the "signed_in_as" email in the var() stash.

See bacds::Scheduler::FederatedAuth for what sets these cookies.

We might not need this for static assets like images or css. Could screen
on the Accept header, Content Negotiation.

=cut

hook before => sub {
    my $login_cookie = cookie LoginMethod
        or return;

    my $login_method = $login_cookie->value;

    given ($login_method) {
        when ('google') {
            my $google_token = cookie GoogleToken
                or return;
            my ($res, $err) = bacds::Scheduler::FederatedAuth
                ->check_google_auth($google_token);
            if ($err) {
                my ($code, $msg) = @$err;
                warn qq{hook before check_google_auth: "$msg" for token '$google_token"};
                return;
            }
            var signed_in_as => $res->{email};
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

            var signed_in_as => $programmer->email;
        }
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

    my ($email, $err) = bacds::Scheduler::FederatedAuth
        ->check_facebook_auth($access_token);

    if ($err) {
        my ($code, $msg) = @$err;
        send_error $msg => $code;
    }

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
    my $event_columns = [
        { name  => "series_id",
          label => "Series",
          type  => "dropdown",
          model_name => "series",
          table_name => "series",
          help_id => "template-help",
          extra_classes => ["series-for-event"],
          display_type => "list-item",
        },
        { name  => "style_id",
          label => "Style",
          type  => "dropdown",
          model_name => "style",
          table_name => "styles",
          allow_multi_select => 1,
          display_type => "list-item",
          required => 1,
        },
        { name  => "venue_id",
          label => "Venue",
          type  => "dropdown",
          model_name => "venue",
          table_name => "venues",
          allow_multi_select => 1,
          display_type => "list-item",
          required => 1,
        },
        { name  => "caller_id",
          label => "Caller",
          type  => "dropdown",
          model_name => "caller",
          table_name => "callers",
          allow_multi_select => 1,
          display_type => "list-item",
        },
        { name  => "parent_org_id",
          label => "Parent Org",
          type  => "dropdown",
          model_name => "parent_org",
          table_name => "parent_orgs",
          allow_multi_select => 1,
          display_type => "list-item",
          required => 1,
        },
        { name  => "name",
          label => "Name (for camps, special events)",
          type  => "text",
        },
        { name  => "start_date",
          label => "Start Date",
          type  => "date",
          required => 1,
        },
        { name  => "start_time",
          label => "Start Time",
          type  => "time",
        },
        { name  => "end_date",
          label => "End Date",
          type  => "date",
        },
        { name  => "end_time",
          label => "End Time",
          type  => "time",
        },
        { name  => "short_desc",
          label => "Short Desc.",
          type  => "textarea",
          required => 1,
        },
        { name  => "custom_url",
          label => "Custom URL",
          type  => "text",
        },
        { name  => "custom_pricing",
          label => "Custom Pricing",
          type  => "textarea",
        },
        { name  => "is_canceled",
          label => "Canceled",
          type  => "bool",
          yes   => "Canceled",
          yes_color => "red",
          no    => "No",
          display_type => "bool-item",
        },
        { name  => "band_id",
          label => "Band",
          type  => "dropdown",
          model_name => "band",
          table_name => "bands",
          allow_multi_select => 1,
          display_type => "list-item",
        },
        { name  => "talent_id",
          label => "Talent",
          type  => "dropdown",
          model_name => "talent",
          table_name => "talent",
          allow_multi_select => 1,
          display_type => "list-item",
        },
        { name  => "is_template",
          type => "hidden",
        },
        { name  => "event_id",
          type => "hidden",
        },
        { name  => "synthetic_name",
          type => "hidden",
        },
    ];
    template 'index' => {
        title => 'Dance Scheduler',
        signed_in_as => vars->{signed_in_as},
        accordions => [
            { label => 'Events',
              modelName => 'event',
              content => template(
                "accordion.tt",
                {
                    form_id => "event-display-form",
                    columns => $event_columns,
                    scripts => ["events"],
                },
                { layout => undef },
              ),
            },
            { label => 'Styles',
              modelName => 'style',
              content => template("styles.tt", {}, { layout=> undef }),
            },
            { label => 'Venues',
              modelName => 'venue',
              content => template("venues.tt", {}, { layout=> undef }),
            },
            { label => 'Series',
              modelName => 'series',
              content => template("series.tt", {}, { layout=> undef }),
            },
            { label => 'Callers',
              modelName => 'caller',
              content => template("callers.tt", {}, { layout=> undef }),
            },
            { label => 'Bands',
              modelName => 'band',
              content => template("bands.tt", {}, { layout=> undef }),
            },
            { label => 'Talent',
              modelName => 'talent',
              content => template("talent.tt", {}, { layout=> undef }),
            },
            { label => 'Parent Org',
              modelName => 'parent_org',
              content => template("parent_org.tt", {}, { layout=> undef }),
            },
            { label => 'Programmers',
              modelName => 'programmer',
              content => template("programmers.tt", {}, { layout=> undef }),
            },
        ],
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

get '/eventAll' => sub {
    my $results = $Results_Class->new;

    $results->data($event_model->get_multiple_rows);

    return $results->format;
};

=head3 GET /eventsUpcoming

Like /eventAll, but just events from yesterday on.

=cut

get '/eventsUpcoming' => sub {
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

get '/event/:event_id' => sub {
    my $event_id = params->{event_id};
    my $results = $Results_Class->new;

    my $event = $event_model->get_row($event_id);
    if ($event) {
        $results->data($event)
    } else {
        $results->add_error(1100, "Nothing Found for event_id $event_id");
    }

    return $results->format;
};


=head3 POST /event/

Create a new event.

=cut

post '/event/' => can_create_event sub {
    my $event = $event_model->post_row(params);
    my $results = $Results_Class->new;

    if ($event) {
        $results->data($event)
    } else {
        $results->add_error(1200, "Insert failed for new event");
    }

    return $results->format;
};


=head3 PUT /event/:event_id

Update an existing event

=cut

put '/event/:event_id' => can_edit_event sub {
    my $event = $event_model->put_row(params);
    my $results = $Results_Class->new;

    if ($event) {
        $results->data($event)
    } else {
        my $event_id = params->{event_id};
        $results->add_error(1300, "Update failed for PUT /event: event_id '$event_id' not found");
    }

    return $results->format;
};


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

=cut

my $style_model = 'bacds::Scheduler::Model::Style';

get '/styleAll' => sub {
    my $results = $Results_Class->new;

    $results->data($style_model->get_multiple_rows);

    return $results->format;
};


=head3 GET /style/:style_id

    "data": {
      "style_id": 6,
      "name": "CONTRA",
      "is_deleted": 0
    }
    "errors": [],


=cut

get '/style/:style_id' => sub {
    my $style_id = params->{style_id};
    my $results = $Results_Class->new;

    my $style = $style_model->get_row($style_id);
    if ($style) {
        $results->data($style)
    } else {
        $results->add_error(1400, "Nothing Found for style_id $style_id");
    }

    return $results->format;
};


post '/style/' => requires_superuser sub {
    my $style = $style_model->post_row(params);
    my $results = $Results_Class->new;

    if ($style) {
        $results->data($style)
    } else {
        $results->add_error(1500, "Insert failed for new style");
    }

    return $results->format;
};


put '/style/:style_id' => requires_superuser sub {
    my $style = $style_model->put_row(params);
    my $results = $Results_Class->new;

    if ($style) {
        $results->data($style)
    } else {
        my $style_id = params->{style_id};
        $results->add_error(1600, "Update failed for PUT /style: style_id '$style_id' not found");
    }

    return $results->format;
};


=head2 Venues

=cut

my $venue_model = 'bacds::Scheduler::Model::Venue';

=head3 GET '/venue/:venue_id'

=cut

get '/venue/:venue_id' => sub {
    my $venue_id = params->{venue_id};
    my $results = $Results_Class->new;

    my $venue = $venue_model->get_row($venue_id);
    if ($venue) {
        $results->data($venue)
    } else {
        $results->add_error(1700, "Nothing Found for venue_id $venue_id");
    }

    return $results->format;
};

=head3 POST /venue/

Create a new venue

=cut

post '/venue/' => requires_superuser sub {
    my $venue = $venue_model->post_row(params);
    my $results = $Results_Class->new;

    if ($venue) {
        $results->data($venue)
    } else {
        $results->add_error(1800, "Insert failed for new venue");
    }

    return $results->format;
};

=head3 put /venue/:venue_id

Update an existing venue.

=cut

put '/venue/:venue_id' => requires_superuser sub {
    my $venue = $venue_model->put_row(params);
    my $results = $Results_Class->new;

    if ($venue) {
        $results->data($venue)
    } else {
        my $venue_id = params->{venue_id};
        $results->add_error(1900, "Update failed for PUT /venue: venue_id '$venue_id' not found");
    }

    return $results->format;
};

=head3 get /venueAll

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


=cut

get '/venueAll' => sub {
    my $results = $Results_Class->new;

    $results->data($venue_model->get_multiple_rows);

    return $results->format;
};


=head2 Series

=cut

my $series_model = 'bacds::Scheduler::Model::Series';
use bacds::Scheduler::Model::Series;


=head3 GET '/series/:series_id'

=cut

get '/series/:series_id' => sub {
    my $series_id = params->{series_id};
    my $results = $Results_Class->new;

    my $series = $series_model->get_row($series_id);
    if ($series) {
        $results->data($series)
    } else {
        $results->add_error(2000, "Nothing Found for series_id $series_id");
    }

    return $results->format;
};

=head3 GET '/series/:series_id/template-event'

=cut

get '/series/:series_id/template-event' => sub {
    my $series_id = params->{series_id};
    my $results = $Results_Class->new;

    my $event = $series_model->get_template_event($series_id);

    #This can be empty, indicating that there isn't a template for this
    #series_id
    if ($event) {
        $results->data($event);
    }
    else {
        $results->data({
            series => [{id => $series_id}],
            is_template => 1,
        });
    }

    return $results->format;
};

=head3 POST /series/

Create a new series

=cut

post '/series/' => requires_superuser sub {
    my $series = $series_model->post_row(params);
    my $results = $Results_Class->new;

    if ($series) {
        $results->data($series)
    } else {
        $results->add_error(2100, "Insert failed for new series");
    }

    return $results->format;
};

=head3 PUT /series/:series_id

Update an existing series.

=cut

put '/series/:series_id' => requires_superuser sub {
    my $series = $series_model->put_row(params);
    my $results = $Results_Class->new;

    if ($series) {
        $results->data($series)
    } else {
        my $series_id = params->{series_id};
        $results->add_error(2200, "Update failed for PUT /series: series_id '$series_id' not found");
    }

    return $results->format;
};

=head3 GET /seriesAll

Return all the non-deleted seriess

=cut

get '/seriesAll' => sub {
    my $results = $Results_Class->new;

    $results->data($series_model->get_multiple_rows);

    return $results->format;
};

=head2 Bands

=cut

my $band_model = 'bacds::Scheduler::Model::Band';
use bacds::Scheduler::Model::Band;


=head3 GET '/band/:band_id'

Get all the info for one band.

=cut

get '/band/:band_id' => sub {
    my $band_id = params->{band_id};
    my $results = $Results_Class->new;

    my $band = $band_model->get_row($band_id);
    if ($band) {
        $results->data($band)
    } else {
        $results->add_error(2300, "Nothing Found for band_id $band_id");
    }

    return $results->format;
};

=head3 POST /band/

Create a new band.

=cut

post '/band/' => requires_login sub {
    my $band = $band_model->post_row(params);
    my $results = $Results_Class->new;

    if ($band) {
        $results->data($band)
    } else {
        $results->add_error(2400, "Insert failed for new band");
    }

    return $results->format;
};

=head3 PUT /band/:band_id

Update an existing band.

=cut

put '/band/:band_id' => requires_login sub {
    my $band = $band_model->put_row(params);
    my $results = $Results_Class->new;

    if ($band) {
        $results->data($band)
    } else {
        my $band_id = params->{band_id};
        $results->add_error(2500, "Update failed for PUT /band: band_id '$band_id' not found");
    }

    return $results->format;
};

=head3 GET /bandAll

Return all the non-deleted bands

=cut

get '/bandAll' => sub {
    my $results = $Results_Class->new;

    $results->data($band_model->get_multiple_rows);

    return $results->format;
};

=head2 Talents

=cut

my $talent_model = 'bacds::Scheduler::Model::Talent';
use bacds::Scheduler::Model::Talent;


=head3 GET '/talent/:talent_id'

Get all the info for one talent.

=cut

get '/talent/:talent_id' => sub {
    my $talent_id = params->{talent_id};
    my $results = $Results_Class->new;

    my $talent = $talent_model->get_row($talent_id);
    if ($talent) {
        $results->data($talent)
    } else {
        $results->add_error(2600, "Nothing Found for talent_id $talent_id");
    }

    return $results->format;
};

=head3 POST /talent/

Create a new talent.

=cut

post '/talent/' => requires_login sub {
    my $talent = $talent_model->post_row(params);
    my $results = $Results_Class->new;

    if ($talent) {
        $results->data($talent)
    } else {
        $results->add_error(2700, "Insert failed for new talent");
    }

    return $results->format;
};

=head3 PUT /talent/:talent_id

Update an existing talent.

=cut

put '/talent/:talent_id' => requires_login sub {
    my $talent = $talent_model->put_row(params);
    my $results = $Results_Class->new;

    if ($talent) {
        $results->data($talent)
    } else {
        my $talent_id = params->{talent_id};
        $results->add_error(2800, "Update failed for PUT /talent: talent_id '$talent_id' not found");
    }

    return $results->format;
};

=head3 GET /talentAll

Return all the non-deleted talents

=cut

get '/talentAll' => sub {
    my $results = $Results_Class->new;

    $results->data($talent_model->get_multiple_rows);

    return $results->format;
};

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

=cut

my $caller_model = 'bacds::Scheduler::Model::Caller';

get '/callerAll' => sub {
    my $results = $Results_Class->new;

    $results->data($caller_model->get_multiple_rows);

    return $results->format;
};


=head3 GET /caller/:caller_id

    "data": {
      "caller_id": 6,
      "name": "Alice Smith",
      "is_deleted": 0
    }
    "errors": [],


=cut

get '/caller/:caller_id' => sub {
    my $caller_id = params->{caller_id};
    my $results = $Results_Class->new;

    my $caller = $caller_model->get_row($caller_id);
    if ($caller) {
        $results->data($caller)
    } else {
        $results->add_error(2900, "Nothing Found for caller_id $caller_id");
    }

    return $results->format;
};

=head3 POST /caller

Create a new caller.

=cut

post '/caller/' => requires_login sub {
    my $caller = $caller_model->post_row(params);
    my $results = $Results_Class->new;

    if ($caller) {
        $results->data($caller)
    } else {
        $results->add_error(3000, "Insert failed for new caller");
    }

    return $results->format;
};

=head3 PUT /caller/:caller_id

Update a caller.

=cut

put '/caller/:caller_id' => requires_login sub {
    my $caller = $caller_model->put_row(params);
    my $results = $Results_Class->new;

    if ($caller) {
        $results->data($caller)
    } else {
        my $caller_id = params->{caller_id};
        $results->add_error(3100, "Update failed for PUT /caller: caller_id '$caller_id' not found");
    }

    return $results->format;
};


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

=cut

my $parent_org_model = 'bacds::Scheduler::Model::ParentOrg';

get '/parent_orgAll' => sub {
    my $results = $Results_Class->new;

    $results->data($parent_org_model->get_multiple_rows);

    return $results->format;
};


=head3 GET /parent_org/:parent_org_id

=cut

get '/parent_org/:parent_org_id' => sub {
    my $parent_org_id = params->{parent_org_id};
    my $results = $Results_Class->new;

    my $parent_org = $parent_org_model->get_row($parent_org_id);
    if ($parent_org) {
        $results->data($parent_org)
    } else {
        $results->add_error(3200, "Nothing Found for parent_org_id $parent_org_id");
    }

    return $results->format;
};

=head3 POST /parent_org

Create a new parent_org.

=cut

post '/parent_org/' => requires_superuser sub {
    my $parent_org = $parent_org_model->post_row(params);
    my $results = $Results_Class->new;

    if ($parent_org) {
        $results->data($parent_org)
    } else {
        $results->add_error(3300, "Insert failed for new parent_org");
    }

    return $results->format;
};

=head3 PUT /parent_org/:parent_org_id

Update a parent_org.

=cut

put '/parent_org/:parent_org_id' => requires_superuser sub {
    my $parent_org = $parent_org_model->put_row(params);
    my $results = $Results_Class->new;

    if ($parent_org) {
        $results->data($parent_org)
    } else {
        my $parent_org_id = params->{parent_org_id};
        $results->add_error(3400, "Update failed for PUT /parent_org: parent_org_id '$parent_org_id' not found");
    }

    return $results->format;
};


=head2 Programmers

The people that are allowed to make changes

=head3 GET /ProgrammerAll

Returns all of the programmers in the db not marked "is_deleted".

=cut

my $programmer_model = 'bacds::Scheduler::Model::Programmer';

get '/programmerAll' => requires_login sub {
    my $results = $Results_Class->new;

    $results->data($programmer_model->get_multiple_rows);

    return $results->format;
};


=head3 GET /programmer/:programmer_id

=cut

get '/programmer/:programmer_id' => requires_login sub {
    my $programmer_id = params->{programmer_id};
    my $results = $Results_Class->new;

    my $programmer = $programmer_model->get_row($programmer_id);
    if ($programmer) {
        $results->data($programmer)
    } else {
        $results->add_error(3200, "Nothing Found for programmer_id $programmer_id");
    }

    return $results->format;
};

=head3 POST /programmer

Create a new programmer.

=cut

post '/programmer/' => requires_superuser sub {
    my $programmer = $programmer_model->post_row(params);
    my $results = $Results_Class->new;

    if ($programmer) {
        $results->data($programmer)
    } else {
        $results->add_error(4300, "Insert failed for new programmer");
    }

    return $results->format;
};

=head3 PUT /programmer/:programmer_id

Update a programmer.

=cut

put '/programmer/:programmer_id' => requires_superuser sub {
    my $programmer = $programmer_model->put_row(params);
    my $results = $Results_Class->new;

    if ($programmer) {
        $results->data($programmer)
    } else {
        my $programmer_id = params->{programmer_id};
        $results->add_error(4400, "Update failed for PUT /programmer: programmer_id '$programmer_id' not found");
    }

    return $results->format;
};

=head3 GET /dancefinder

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
            meta_tags => _virtual_include('/shared/meta-tags.html'),
            navbar    => _virtual_include('/shared/navbar.html'),
            menu      => _virtual_include('/shared/menu.html'),
            copyright => _virtual_include('/shared/copyright.html'),
        },

    },
    # get the wrapper from views/layouts/<whatever>
    { layout => 'dancefinder' },

};

=head3 GET /dancefinder-results

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
        if ($event->bands != 0) {
            $titlestring .= ' Music by ';
            $titlestring .= join ', ', map $_->name, $event->bands->all;
            $titlestring .= '.';
        }

        $titlestring .= ' - '.$event->short_desc
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
] => sub {

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

    if (my $sidebar = $data->{series}->sidebar) {
        $sidebar =~ s{<!--#include virtual="(.+?)" -->}
                     {_virtual_include($1)}eg;
        $data->{sidebar} = $sidebar;
    }
    if (my $display_text = $data->{series}->display_text) {
        $display_text =~ s{<!--#include virtual="(.+?)" -->}
                          {_virtual_include($1)}eg;
        $data->{display_text} = $display_text;
    }

    $data->{ssi_uri_for} = \&ssi_uri_for;

    template('serieslister/upcoming-events', $data,
        {layout => undef},
    );
};


=head2 document_args

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

=head2 ssi_uri_for

If running through a virtual include, uses the original request
path from REQUEST_URI (see notes in document_args()), otherwise
uses the application path.

=cut

sub ssi_uri_for {
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
