script_dir=$(dirname "$0")

schema_files="
    bands.sql
    styles.sql
    talent.sql
    venues.sql
    callers.sql
    series.sql
    events.sql
    parent_orgs.sql
    event_band_map.sql
    event_callers_map.sql
    event_parent_orgs_map.sql
    event_styles_map.sql
    event_talent_map.sql
    event_venues_map.sql
    band_membership.sql
    programmers.sql
    programmer_series_map.sql
    programmer_events_map.sql
    audit_logs.sql
"

for schema_file in $schema_files ; do
	echo $schema_file
	mysql -uscheduler --password=`cat /var/www/bacds.org/dance-scheduler/private/mysql-password` schedule < $script_dir/$schema_file
done
