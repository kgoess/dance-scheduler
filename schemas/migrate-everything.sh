#!/bin/sh -x
set -e

script_dir=$(dirname "$0")

export PERL5LIB=$script_dir/../lib:$PERL5LIB

$script_dir/../bin/migrate-styles.pl
$script_dir/../bin/migrate-venues.pl
$script_dir/../bin/migrate-callers.pl
$script_dir/../bin/migrate-parent-orgs.pl
$script_dir/../bin/migrate-series.pl
$script_dir/../bin/migrate-events.pl
