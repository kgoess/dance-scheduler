#!/bin/sh -x

../bin/migrate-series.pl
../bin/migrate-styles.pl
../bin/migrate-venues.pl
../bin/migrate-events.pl
