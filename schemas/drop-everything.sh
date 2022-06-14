script_dir=$(dirname "$0")

tables="
    event_band_map
    event_callers_map
    event_parent_orgs_map
    event_styles_map
    event_talent_map
    event_venues_map
    band_membership
    events
    bands
    styles
    talent
    venues
    callers
    series
    parent_orgs
"

for table in $tables; do
	echo $table
	mysql -uscheduler --password=`cat ~/.mysql-password` schedule -e "drop table $table"
done
