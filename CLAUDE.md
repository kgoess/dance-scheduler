# dance-scheduler

Dancer2 + DBIx::Class app behind bacds.org: the admin scheduler, the public
"Unearth" site pages, and the member self-service portal backed by CiviCRM.
README.md covers setup, schema changes, and install in more detail.

## Dev environment

The app can't run on the Mac checkout (system perl is too old; the code needs
5.32). Develop and test on the dev host `maud`:

    ssh maud
    cd ~/git/dance-scheduler
    eval $(perl -Mlocal::lib=/var/lib/dance-scheduler)

Start the web app (uses the `schedule_test` database):

    plackup -Ilib -p 5000 bin/app.psgi

maud has `~/.civicrm-api-key`, so live CiviCRM API calls work there.

To test uncommitted changes from a local checkout without touching maud's
checkout, copy the tree to a scratch dir and run the tests there:

    rsync -a --exclude .git --exclude testdb ./ maud:/tmp/ds-test/
    ssh maud 'cd /tmp/ds-test && eval $(perl -Mlocal::lib=/var/lib/dance-scheduler) && prove -Ilib t/530-member-portal.t'

Remove the scratch dir afterwards.

## Tests

- Run one file with `prove -Ilib t/NNN-name.t`; run everything with
  `perl Makefile.PL && make && make test`.
- Tests use a throwaway test DB set up by `setup_test_db` in
  `bacds::Scheduler::Util::Test`.
- `t/530-member-portal.t` mocks the `bacds::Scheduler::CiviCRM` methods, so it
  needs no network or API key. To check real CiviCRM behaviour, call the
  client on maud.

## Databases

- `schedule` is production. Don't write to it.
- `schedule_test` is for development. `schemas/copy-prod-to-test.sh` refreshes
  it from production.

## CiviCRM / member portal

- Client: `lib/bacds/Scheduler/CiviCRM.pm`, which talks to
  https://bacds.civicrm.org. Its POD covers the flow, configuration files, and
  links to the API explorers.
- Portal logic: `lib/bacds/Scheduler/Model/MemberPortal.pm`. Routes under
  `/unearth/member` are in `lib/bacds/Scheduler.pm`; templates are in
  `views/member/`.
- Use APIv4 for data. APIv3 is used only for `MessageTemplate.send`.
- APIv4 action parameters are camelCase (e.g. `Contact.getChecksum` takes
  `contactId`). Custom fields are addressed as `GroupName.field_name`, not by
  ID.
- Read-only API calls against the live CiviCRM are fine for checking
  behaviour. Ask before making calls that create, update, or send anything.

## Git

- Branch from `main` with a `kg-` prefix, then open PRs against `main`.
- The checkout has many untracked scratch files (`*.vim`, `xx*`, `testdb`,
  notes). Stage only the files you changed; never use `git add -A`.
