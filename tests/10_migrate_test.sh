#!/usr/bin/env bash

set -eu
for helper in $(dirname $0)/helpers/*; do source $helper; done

######################################################################
### pg-copy-ch token

describe "pg-copy-ch init"
it "creates config"
  run  pg-copy-ch init
