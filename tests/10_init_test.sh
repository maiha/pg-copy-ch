#!/usr/bin/env bash

set -eu
for helper in $(dirname $0)/helpers/*; do source $helper; done

######################################################################
### pg-copy-ch init

PG_HOST=${PG_HOST:-localhost}
CH_HOST=${CH_HOST:-localhost}

describe "pg-copy-ch init config"
it "creates .pg-copy-ch/config"
  rm -f .pg-copy-ch/config
  @run  pg-copy-ch init config
  @run  test -f .pg-copy-ch/config

it 'contains [postgres] host = "localhost"'
  grep -A1 '\[postgres\]' .pg-copy-ch/config | tail -1 > run.out.0
  @assert "host = \"localhost\""

it 'contains [clickhouse] host = "localhost"'
  grep -A1 '\[clickhouse\]' .pg-copy-ch/config | tail -1 > run.out.0
  @assert "host = \"localhost\""

describe "pg-copy-ch init config --pg-host ${PG_HOST} --ch-host ${CH_HOST}"
it "creates .pg-copy-ch/config"
  rm -f .pg-copy-ch/config
  @run  pg-copy-ch init config --pg-host ${PG_HOST} --ch-host ${CH_HOST}
  @run  test -f .pg-copy-ch/config

it "contains [postgres] host = \"${PG_HOST}\""
  grep -A1 '\[postgres\]' .pg-copy-ch/config | tail -1 > run.out.0
  @assert "host = \"${PG_HOST}\""

it "contains [clickhouse] host = \"${CH_HOST}\""
  grep -A1 '\[clickhouse\]' .pg-copy-ch/config | tail -1 > run.out.0
  @assert "host = \"${CH_HOST}\""
