#!/bin/sh -x

export PERL5LIB=../lib:$PERL5LIB

../bin/migrate-series.pl
../bin/migrate-styles.pl
../bin/migrate-venues.pl
../bin/migrate-callers.pl
../bin/migrate-events.pl
