#!/usr/bin/env bash

set -eu
for helper in $(dirname $0)/helpers/*; do source $helper; done

PG_HOST=${PG_HOST:-localhost}
CH_HOST=${CH_HOST:-localhost}

######################################################################
### pg-copy-ch init config

describe "pg-copy-ch init config"
it "creates .pg-copy-ch/config"
  rm -f .pg-copy-ch/config
  @run  pg-copy-ch init config
  @run  test -f .pg-copy-ch/config

it 'contains [postgres] host = "localhost"'
  grep -A1 '\[postgres\]' .pg-copy-ch/config | tail -1 > run.out
  @assert "host = \"localhost\""

it 'contains [clickhouse] host = "localhost"'
  grep -A1 '\[clickhouse\]' .pg-copy-ch/config | tail -1 > run.out
  @assert "host = \"localhost\""

describe "pg-copy-ch init config --pg-host ${PG_HOST} --ch-host ${CH_HOST}"
it "creates .pg-copy-ch/config"
  rm -f .pg-copy-ch/config
  @run  pg-copy-ch init config --pg-host ${PG_HOST} --ch-host ${CH_HOST}
  @run  test -f .pg-copy-ch/config

it "contains [postgres] host = \"${PG_HOST}\""
  grep -A1 '\[postgres\]' .pg-copy-ch/config | tail -1 > run.out
  @assert "host = \"${PG_HOST}\""

it "contains [clickhouse] host = \"${CH_HOST}\""
  grep -A1 '\[clickhouse\]' .pg-copy-ch/config | tail -1 > run.out
  @assert "host = \"${CH_HOST}\""

######################################################################
### pg-copy-ch init tables

describe "pg-copy-ch init tables"
it "executes psql -h pg -p 5432 -U postgres postgres -w -f .pg-copy-ch/pg/meta.sql"
  # dryrun
  @run  pg-copy-ch init tables -n
  # remove ansi colors
  sed -i -r "s:\x1B\[[0-9;]*[mK]::g" run.out
  @assert -1 "(dryrun) psql -h pg -p 5432 -U postgres postgres -w -f .pg-copy-ch/pg/meta.sql > .pg-copy-ch/pg/meta.csv.tmp"
