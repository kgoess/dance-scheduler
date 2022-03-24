for table in series.sql events.sql bands.sql styles.sql talent.sql venues.sql callers.sql event_band_map.sql event_callers_map.sql event_styles_map.sql event_talent_map.sql event_venues_map.sql band_membership.sql; do
	echo $table
	mysql -uscheduler --password=`cat ~/.mysql-password` schedule < $table
done
