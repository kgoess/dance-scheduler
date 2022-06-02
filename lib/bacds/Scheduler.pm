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

use bacds::Scheduler::Model::Event;
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
        "start_time": "2022-06-08T00:00:00",
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

Like /eventsAll, but just events from yesterday on.

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
      "start_time": "2022-06-22T00:00:00",
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

    my $venue = $venue_model->get_venue($venue_id);
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
    my $data = {};
    foreach my $field (qw/
        vkey
        hall_name
        address
        city
        zip
        comment
        is_deleted
        /){
        $data->{$field} = params->{$field};
    };

    my $venue = $venue_model->post_venue($data);
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
    my $data = {};
    foreach my $field (qw/
        venue_id
        vkey
        hall_name
        address
        city
        zip
        comment
        is_deleted
        /){
        $data->{$field} = params->{$field};
    };

    # FIXME otherwise insert error:
    # DBD::mysql::st execute failed: Incorrect integer value: '' for column `schedule`.`venues`.`is_deleted`
    if (! length $data->{is_deleted}) {
        $data->{is_deleted} = 0;
    }

    my $venue = $venue_model->put_venue($data);
    my $results = Results->new;

    if($venue){
        $results->data($venue)
    }
    else{
        $results->add_error(1900, "Update failed for new $data->{venue_id}");
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

    $results->data($venue_model->get_venues);

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
        $results->add_error(1800, "Nothing Found for series_id $series_id");
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
        $results->add_error(1900, "Insert failed for new series");
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
        $results->add_error(2100, "Update failed for series");
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
            $self->data ? (data => $self->data) : (),
            $self->errors ? (errors => [
                map { {
                    msg => $_->{msg},
                    num => $_->{num},
                } } @{$self->errors}
            ]) : (),
        });
    }
}


true;
