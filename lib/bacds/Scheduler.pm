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
#All error nums in this file are 1###
use 5.16.0;
use warnings;

use Dancer2;
use Data::Dump qw/dump/;

use bacds::Scheduler::Model::Caller;
use bacds::Scheduler::Model::Event;
use bacds::Scheduler::Model::ParentOrg;
use bacds::Scheduler::Model::Style;
use bacds::Scheduler::Model::Venue;

our $VERSION = '0.1';

=head2 main/root

The display page. This is the only endpoint that serves html.

=cut

get '/' => sub {
    template 'index' => {
        title => 'Dance Schedule',
        accordions => [
            { label => 'Events',
              modelName => 'event',
              content => template("events.tt", {}, { layout=> undef }),
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
    my $results = Results->new;
    
    $results->data($event_model->get_multiple_rows);
    
    return $results->format;
};

=head3 GET /eventsUpcoming

Like /eventAll, but just events from yesterday on.

=cut

get '/eventsUpcoming' => sub {
    my $results = Results->new;

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
    my $results = Results->new;

    my $event = $event_model->get_row($event_id);
    if($event){
        $results->data($event)
    }
    else{
        $results->add_error(1100, "Nothing Found for event_id $event_id");
    }

    return $results->format;
};


=head3 POST /event/

Create a new event.

=cut

post '/event/' => sub {
    my $event = $event_model->post_row(params);
    my $results = Results->new;

    if($event){
        $results->data($event)
    }
    else{
        $results->add_error(1200, "Insert failed for new event");
    }

    return $results->format;
};


=head3 PUT /event/:event_id

Update an existing event

=cut

put '/event/:event_id' => sub {
    my $event = $event_model->put_row(params);
    my $results = Results->new;

    if($event){
        $results->data($event)
    }
    else{
        $results->add_error(1300, "Update failed for new event");
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
    my $results = Results->new;

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
    my $results = Results->new;

    my $style = $style_model->get_row($style_id);
    if($style){
        $results->data($style)
    }
    else{
        $results->add_error(1400, "Nothing Found for style_id $style_id");
    }

    return $results->format;
};


post '/style/' => sub {
    my $style = $style_model->post_row(params);
    my $results = Results->new;

    if($style){
        $results->data($style)
    }
    else{
        $results->add_error(1500, "Insert failed for new style");
    }

    return $results->format;
};


put '/style/:style_id' => sub {
    my $style = $style_model->put_row(params);
    my $results = Results->new;

    if($style){
        $results->data($style)
    }
    else{
        $results->add_error(1600, "Update failed for new style");
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
    my $results = Results->new;

    my $venue = $venue_model->get_row($venue_id);
    if($venue){
        $results->data($venue)
    }
    else{
        $results->add_error(1700, "Nothing Found for venue_id $venue_id");
    }

    return $results->format;
};

=head3 POST /venue/

Create a new venue

=cut

post '/venue/' => sub {
    my $venue = $venue_model->post_row(params);
    my $results = Results->new;

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

put '/venue/:venue_id' => sub {
    my $venue = $venue_model->put_row(params);
    my $results = Results->new;

    if($venue){
        $results->data($venue)
    }
    else{
        $results->add_error(1900, "Update failed for venue");
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
    my $results = Results->new;

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
    my $results = Results->new;

    my $series = $series_model->get_row($series_id);
    if($series){
        $results->data($series)
    }
    else{
        $results->add_error(2000, "Nothing Found for series_id $series_id");
    }

    return $results->format;
};

=head3 GET '/series/:series_id/template-event'

=cut

get '/series/:series_id/template-event' => sub {
    my $series_id = params->{series_id};
    my $results = Results->new;

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

post '/series/' => sub {
    my $series = $series_model->post_row(params);
    my $results = Results->new;

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

put '/series/:series_id' => sub {
    my $series = $series_model->put_row(params);
    my $results = Results->new;

    if($series){
        $results->data($series)
    }
    else{
        $results->add_error(2200, "Update failed for series");
    }

    return $results->format;
};

=head3 GET /seriesAll

Return all the non-deleted seriess

=cut

get '/seriesAll' => sub {
    my $results = Results->new;

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
    my $results = Results->new;

    my $band = $band_model->get_row($band_id);
    if($band){
        $results->data($band)
    }
    else{
        $results->add_error(2300, "Nothing Found for band_id $band_id");
    }

    return $results->format;
};

=head3 POST /band/

Create a new band.

=cut

post '/band/' => sub {
    my $band = $band_model->post_row(params);
    my $results = Results->new;

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

put '/band/:band_id' => sub {
    my $band = $band_model->put_row(params);
    my $results = Results->new;

    if($band){
        $results->data($band)
    }
    else{
        $results->add_error(2500, "Update failed for band");
    }

    return $results->format;
};

=head3 GET /bandAll

Return all the non-deleted bands

=cut

get '/bandAll' => sub {
    my $results = Results->new;

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
    my $results = Results->new;

    my $talent = $talent_model->get_row($talent_id);
    if($talent){
        $results->data($talent)
    }
    else{
        $results->add_error(2600, "Nothing Found for talent_id $talent_id");
    }

    return $results->format;
};

=head3 POST /talent/

Create a new talent.

=cut

post '/talent/' => sub {
    my $talent = $talent_model->post_row(params);
    my $results = Results->new;

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

put '/talent/:talent_id' => sub {
    my $talent = $talent_model->put_row(params);
    my $results = Results->new;

    if($talent){
        $results->data($talent)
    }
    else{
        $results->add_error(2800, "Update failed for talent");
    }

    return $results->format;
};

=head3 GET /talentAll

Return all the non-deleted talents

=cut

get '/talentAll' => sub {
    my $results = Results->new;

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
    my $results = Results->new;

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
    my $results = Results->new;

    my $caller = $caller_model->get_row($caller_id);
    if($caller){
        $results->data($caller)
    }
    else{
        $results->add_error(2900, "Nothing Found for caller_id $caller_id");
    }

    return $results->format;
};

=head3 POST /caller

Create a new caller.

=cut

post '/caller/' => sub {
    my $caller = $caller_model->post_row(params);
    my $results = Results->new;

    if($caller){
        $results->data($caller)
    }
    else{
        $results->add_error(3000, "Insert failed for new caller");
    }

    return $results->format;
};

=head3 PUT /caller/:caller_id

Update a caller.

=cut

put '/caller/:caller_id' => sub {
    my $caller = $caller_model->put_row(params);
    my $results = Results->new;

    if($caller){
        $results->data($caller)
    }
    else{
        $results->add_error(3100, "Update failed for new caller");
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
    my $results = Results->new;

    $results->data($parent_org_model->get_multiple_rows);

    return $results->format;
};


=head3 GET /parent_org/:parent_org_id

=cut

get '/parent_org/:parent_org_id' => sub {
    my $parent_org_id = params->{parent_org_id};
    my $results = Results->new;

    my $parent_org = $parent_org_model->get_row($parent_org_id);
    if($parent_org){
        $results->data($parent_org)
    }
    else{
        $results->add_error(3200, "Nothing Found for parent_org_id $parent_org_id");
    }

    return $results->format;
};

=head3 POST /parent_org

Create a new parent_org.

=cut

post '/parent_org/' => sub {
    my $parent_org = $parent_org_model->post_row(params);
    my $results = Results->new;

    if($parent_org){
        $results->data($parent_org)
    }
    else{
        $results->add_error(3300, "Insert failed for new parent_org");
    }

    return $results->format;
};

=head3 PUT /parent_org/:parent_org_id

Update a parent_org.

=cut

put '/parent_org/:parent_org_id' => sub {
    my $parent_org = $parent_org_model->put_row(params);
    my $results = Results->new;

    if($parent_org){
        $results->data($parent_org)
    }
    else{
        $results->add_error(3400, "Update failed for new parent_org");
    }

    return $results->format;
};

=head1 Results

A little internal class to collect any errors and format the results:

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

package Results {
    use Dancer2;
    use Data::Dump qw/dump/;
    use Class::Accessor::Lite (
        new => 0,
        rw => [ qw(data errors) ],
    );

    sub new {
        return bless {data=>'',errors=>[]};
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
        return encode_json({
            data => $self->data,
            errors => [
                map { {
                    msg => $_->{msg},
                    num => $_->{num},
                } } @{$self->errors}
            ],
        });
    }
}


true;
