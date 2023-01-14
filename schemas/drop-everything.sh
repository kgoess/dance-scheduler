
tables="
    event_band_map
    event_callers_map
    event_parent_orgs_map
    event_styles_map
    event_talent_map
    event_venues_map
    programmer_series_map
    programmer_events_map
    band_membership
    events
    series
    styles
    talent
    bands
    venues
    callers
    audit_logs
    programmers
    parent_orgs
"

for table in $tables; do
	echo $table
	mysql -uscheduler --password=`cat /var/www/bacds.org/dance-scheduler/private/mysql-password` schedule -e "drop table $table"
done
