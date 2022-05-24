for table in event_band_map event_callers_map event_styles_map event_talent_map event_venues_map band_membership events bands styles talent venues callers series ; do
	echo $table
	mysql -uscheduler --password=`cat ~/.mysql-password` schedule -e "drop table $table"
done
