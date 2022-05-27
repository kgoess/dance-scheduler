package bacds::Scheduler;
#All error nums in this file are 1###
use 5.16.0;
use warnings;

use Dancer2;
use Data::Dump qw/dump/;

our $VERSION = '0.1';

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
        ],
    };
};




#Events
my $event_model = 'bacds::Scheduler::Model::Event';
use bacds::Scheduler::Model::Event;

get '/eventAll' => sub {
    my $results = Results->new;
    
    $results->data($event_model->get_events);
    
    return $results->format;
};

get '/eventsUpcoming' => sub {
    my $results = Results->new;

    $results->data($event_model->get_upcoming_events);

    return $results->format;
};

get '/event/:event_id' => sub {
    my $event_id = params->{event_id};
    my $results = Results->new;

    my $event = $event_model->get_event($event_id);
    if($event){
        $results->data($event)
    }
    else{
        $results->add_error(1100, "Nothing Found for event_id $event_id");
    }

    return $results->format;
};


post '/event/' => sub {
    my $data = {};
    foreach my $field (qw/
        name
        end_time
        start_time
        is_camp
        long_desc
        short_desc
        series_id
        style_id
        venue_id
        /){
        $data->{$field} = params->{$field};
    };

    my $event = $event_model->post_event($data);
    my $results = Results->new;

    if($event){
        $results->data($event)
    }
    else{
        $results->add_error(1200, "Insert failed for new event");
    }

    return $results->format;
};


put '/event/:event_id' => sub {
    my $data = {};
    foreach my $field (qw/
        event_id
        name
        end_time
        start_time
        is_camp
        long_desc
        short_desc
        series_id
        style_id
        venue_id
        /){
        $data->{$field} = params->{$field};
    };
    
    my $event = $event_model->put_event($data);
    my $results = Results->new;

    if($event){
        $results->data($event)
    }
    else{
        $results->add_error(1300, "Update failed for new $data->{event_id}");
    }
    
    return $results->format;
};



#Styles
my $style_model = 'bacds::Scheduler::Model::Style';
use bacds::Scheduler::Model::Style;


get '/styleAll' => sub {
    my $results = Results->new;
    
    $results->data($style_model->get_styles);
    
    return $results->format;
};


get '/style/:style_id' => sub {
    my $style_id = params->{style_id};
    my $results = Results->new;

    my $style = $style_model->get_style($style_id);
    if($style){
        $results->data($style)
    }
    else{
        $results->add_error(1400, "Nothing Found for style_id $style_id");
    }

    return $results->format;
};


post '/style/' => sub {
    my $data = {};
    $data->{name} = params->{name};

    my $style = $style_model->post_style($data);
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
    my $data = {};
    foreach my $field (qw/
        style_id
        name
        /){
        $data->{$field} = params->{$field};
    };
    
    my $style = $style_model->put_style($data);
    my $results = Results->new;

    if($style){
        $results->data($style)
    }
    else{
        $results->add_error(1600, "Update failed for new $data->{style_id}");
    }
    
    return $results->format;
};


=head2 Venues

=cut

my $venue_model = 'bacds::Scheduler::Model::Venue';
use bacds::Scheduler::Model::Venue;


=head3 get '/venue/:venue_id'

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

=head3 post /venue/

Create a new venue

=cut

post '/venue/' => sub {
    my $data = {};
    foreach my $field (qw/
        hall_name
        address
        city
        zip
        comment
        is_deleted
        /){
        $data->{$field} = params->{$field};
    };

    # FIXME "name" is dicated by the javascript
    # see the FIXME in Model/Venue.pm
    $data->{vkey} = params->{name};

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
        hall_name
        address
        city
        zip
        comment
        is_deleted
        /){
        $data->{$field} = params->{$field};
    };

    # FIXME "name" is dicated by the javascript
    # see the FIXME in Model/Venue.pm
    $data->{vkey} = params->{name};

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

=cut

get '/venueAll' => sub {
    my $results = Results->new;
    
    $results->data($venue_model->get_venues);
    
    return $results->format;
};

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
