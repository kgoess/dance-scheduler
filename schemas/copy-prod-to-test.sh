
tables="
    event_band_map
    event_callers_map
    event_parent_orgs_map
    event_styles_map
    event_talent_map
    event_venues_map
    event_teams_map
    programmer_series_map
    programmer_events_map
    band_membership
    team_styles_map
    events
    teams
    series
    styles
    talent
    bands
    venues
    callers
    audit_logs
    parent_orgs
"

# leaving programmers so we don't have to keep re-establishing the test passwords
# programmers

for table in $tables; do
    echo $table
	mysql -uscheduler_test --password=`cat ~/.mysql-password` schedule_test -e "drop table $table"
done

set -x

sudo mysqldump -uroot schedule > schedule.dump
sudo mysql -uroot schedule_test < schedule.dump
rm schedule.dump
