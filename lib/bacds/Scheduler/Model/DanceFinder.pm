=head1 NAME

bacds::Scheduler::Model::DanceFinder

=head1 DESCRIPTION

This is the db access stuff for the dancefinder

=head2 METHODS

=cut

package bacds::Scheduler::Model::DanceFinder;

use 5.16.0;
use warnings;

use Data::Dump qw/dump/;

use bacds::Scheduler::Util::Db qw/get_dbh/;
use bacds::Scheduler::Util::Time qw/get_today/;
use DateTime::Format::ISO8601;

=head2 related_entities_for_upcoming_events

Returns the callers, venues, bands, musos, styles and role pairs on
upcoming events (today onward, not deleted), for the dancefinder form's
dropdowns:

    {
        callers    => { $caller_id => $caller_row, ... },
        venues     => { ... },
        bands      => { ... },
        musos      => { ... },  # talent on the events, and in their bands
        styles     => { ... },
        role_pairs => { ... },
    }

Deleted entries are left out. Each list is one small query, with the
upcoming events as a subquery. This used to load every upcoming event with
all of its related rows in one big JOIN and collect them in perl, which
took over a second for a few months of events, nearly all of it spent
building objects from the JOIN's rows.

=cut

sub related_entities_for_upcoming_events {
    my ($class) = @_;

    my $dbh = get_dbh(debug => 0);

    my $upcoming_event_ids = $dbh->resultset('Event')->search(
        {
            start_date => { '>=' => get_today()->ymd },
            '-not_bool' => 'is_deleted',
        },
        { columns => ['event_id'] },
    )->as_query;

    # ids from a mapping table, for the upcoming events
    my $ids_on_upcoming_events = sub {
        my ($map_source, $id_column) = @_;
        return $dbh->resultset($map_source)->search(
            { event_id => { -in => $upcoming_event_ids } },
            { columns => [$id_column] },
        )->as_query;
    };

    # the non-deleted rows of $source whose $id_column is in any of the
    # @id_queries
    my $rows_by_id = sub {
        my ($source, $id_column, @id_queries) = @_;
        my $rs = $dbh->resultset($source)->search({
            is_deleted => 0,
            -or => [ map { { $id_column => { -in => $_ } } } @id_queries ],
        });
        return { map { $_->$id_column => $_ } $rs->all };
    };

    # musos are talent on the events themselves, plus the members of the
    # events' bands
    my $band_member_ids = $dbh->resultset('BandMembership')->search(
        { band_id => { -in => $ids_on_upcoming_events->('EventBandMap', 'band_id') } },
        { columns => ['talent_id'] },
    )->as_query;

    return {
        callers    => $rows_by_id->(Caller => 'caller_id',
                          $ids_on_upcoming_events->('EventCallersMap', 'caller_id')),
        venues     => $rows_by_id->(Venue => 'venue_id',
                          $ids_on_upcoming_events->('EventVenuesMap', 'venue_id')),
        bands      => $rows_by_id->(Band => 'band_id',
                          $ids_on_upcoming_events->('EventBandMap', 'band_id')),
        musos      => $rows_by_id->(Talent => 'talent_id',
                          $ids_on_upcoming_events->('EventTalentMap', 'talent_id'),
                          $band_member_ids),
        styles     => $rows_by_id->(Style => 'style_id',
                          $ids_on_upcoming_events->('EventStylesMap', 'style_id')),
        role_pairs => $rows_by_id->(RolePair => 'role_pair_id',
                          $ids_on_upcoming_events->('EventRolePairsMap', 'role_pair_id')),
    };
}

=head2 search_events

This one searches the events table, takes a bunch of args, and makes sure that
all the related entities come back with the events.

Returns a $rs for you to call `->all` on. You can't do `->next` because of this
warning:

    DBIx::Class::ResultSet::_construct_results(): Unable to properly collapse
    has_many results in iterator mode due to order criteria - performed an
    eager cursor slurp underneath. Consider using ->all() instead at

=cut

sub search_events {
    my ($class, %args) = @_;

    my $start_date_arg = delete $args{start_date};
    my $end_date_arg   = delete $args{end_date};
    my $series_xid_arg = delete $args{series_xid};
    my $caller_arg     = delete $args{caller}    || [];
    my $venue_arg      = delete $args{venue}     || [];
    my $band_arg       = delete $args{band}      || [];
    my $muso_arg       = delete $args{muso}      || [];
    my $style_arg      = delete $args{style}     || [];
    my $team_arg       = delete $args{team}      || [];
    my $parent_org_arg = delete $args{parent_org}|| [];
    my $role_pair_arg  = delete $args{role_pair} || [];
    my $role_pair_allow_blank = delete $args{role_pair_allow_blank} || 0;
    my $dbix_debug     = delete $args{dbix_debug};
    # db and dbuser are for dancefinder.pl
    my $db_arg         = delete $args{db};
    my $dbuser_arg     = delete $args{dbuser};
    die "unrecognized args in call to search_events ".join(', ', sort keys %args)
        if %args;

    my $dbh = get_dbh(debug => $dbix_debug, db => $db_arg, user => $dbuser_arg);

    # These prefetches means all the data is fetched with one big
    # JOIN, you can verify that by adding debug=>1 in the
    # get_dbh call above
    my @prefetches = (
        'series',
        {event_callers_maps => 'caller'},
        {event_styles_maps => 'style'},
        {event_talent_maps => 'talent'},
        {event_venues_maps => 'venue'},
        {event_parent_orgs_maps => 'parent_org'},
        {event_team_maps => 'team'},
        {event_band_maps => {band => { band_memberships => 'talent'}}},
        {event_role_pairs_maps => 'role_pair'}
    );

    my @joins = (
        @$caller_arg ? 'event_callers_maps' : (),
        @$venue_arg ? 'event_venues_maps' : (),
        @$style_arg ? 'event_styles_maps' : (),
        @$muso_arg ? 'event_talent_maps' : (),
        @$band_arg ? 'event_band_maps' : (),
        @$team_arg ? 'event_team_maps' : (),
        @$role_pair_arg ? 'event_role_pairs_maps' : (),
    );

    my $start_datetime;
    if ($start_date_arg) {
        if (ref $start_date_arg) { # it is a datetime object
            $start_datetime = $start_date_arg;
        } else { # it is an iso8601 string
            $start_datetime = DateTime::Format::ISO8601->parse_datetime($start_date_arg);
        }
    } else {
        $start_datetime = get_today();
    }
    
    my $start_date = $dbh->storage->datetime_parser->format_datetime($start_datetime->truncate(to => 'day'));

    my $end_date;
    if ($end_date_arg){
        my $end_datetime;
        if (ref $end_date_arg){
            $end_datetime = $end_date_arg;
        } else {
            $end_datetime = DateTime::Format::ISO8601->parse_datetime($end_date_arg);
        }
        $end_date = $dbh->storage->datetime_parser->format_datetime($end_datetime->truncate(to => 'day'));
    }

    my @role_search;
    if ($role_pair_allow_blank){
        my $role_non_blank = $dbh->resultset('EventRolePairsMap')->search({},{
            columns => 'event_id',
            distinct => 1
        });
        @role_search = @$role_pair_arg
            ? (
            -or => [
                'event_role_pairs_maps.role_pair_id' => $role_pair_arg,
                'me.event_id' => { -not_in => $role_non_blank->as_query}
            ])
            : ('me.event_id' => { -not_in => $role_non_blank->as_query});
    } else {
        @role_search = @$role_pair_arg ? ('event_role_pairs_maps.role_pair_id' => $role_pair_arg)   : ();
    }

    # wrt join and prefetch see:
    # https://metacpan.org/dist/DBIx-Class/view/lib/DBIx/Class/Manual/Cookbook.pod#Using-joins-and-prefetch
    my $subquery = $dbh->resultset('Event')->search(
        {
            '-not_bool' => 'is_deleted',
            start_date =>
                $end_date
                ? { '-between' => [$start_date, $end_date] }
                : { '>=' => $start_date },
            $series_xid_arg ? ('series_xid' => $series_xid_arg) : (),
            @$caller_arg ? ('event_callers_maps.caller_id' => $caller_arg) : (),
            @$venue_arg  ? ('event_venues_maps.venue_id'   => $venue_arg)  : (),
            @$style_arg  ? ('event_styles_maps.style_id'   => $style_arg)  : (),
            @$muso_arg   ? ('event_talent_maps.talent_id'  => $muso_arg)   : (),
            @$band_arg   ? ('event_band_maps.band_id'      => $band_arg)   : (),
            @$team_arg   ? ('event_team_maps.team_id'     => $team_arg)   : (),
            @$parent_org_arg   ? ('event_parent_orgs_maps.parent_org_id'     => $parent_org_arg)   : (),
            @role_search,
        },
        {
            join => \@joins,
            select => 'event_id',
        },
    );
    my $query = $dbh->resultset('Event')->search(
        {
            'me.event_id' => { -in => $subquery->as_query },
        },
        {
            # this might be the place to add sorting for events on the same day
            # with different parent_orgs so that BACDS comes first
            order_by => ['start_date', 'start_time'],
            prefetch => \@prefetches,
        },
    );

    return $query;
}

1;
