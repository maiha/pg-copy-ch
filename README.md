# pg-copy-ch [![Build Status](https://travis-ci.org/maiha/pg-copy-ch.svg?branch=master)](https://travis-ci.org/maiha/pg-copy-ch)

Simply copy the current PostgreSQL data to ClickHouse
* Simple    : Just dumps and imports, so it works with older versions like 9.x.
* Handy     : Static single binary, so you can install it just by wget or cp.
* Automatic : Create ClickHouse tables from PostgreSQL automatically.
* Easy      : Include/Exclude tables by regex. Skip by max data count, ttl.

```console
$ pg-copy-ch copy -t table1,table2
$ pg-copy-ch copy --all
```

## Installation
* **psql** : required for PostgreSQL client
* **clickhouse-client** : required for ClickHouse client
* x86_64 static binary: https://github.com/maiha/pg-copy-ch/releases

```console
$ wget https://github.com/maiha/pg-copy-ch/releases/latest/download/pg-copy-ch
```

## Usage

All commands can be executed with arguments, as shown below.

```console
$ pg-copy-ch copy --pg-host=pg-prod --pg-user=reader --pg-db=system --tables=users,roles,schedules ...
```

But it is recommended that you create a configuration file,
as doing this every time is painful and error-prone.

### config

```console
$ pg-copy-ch init
Initialized empty cofig in .pg-copy-ch/config

$ cat .pg-copy-ch/config
[postgres]
host = "localhost"
port = 5432
user = "postgres"
...
```

If you initialize with the pg connection information, the table names are also written out.

```console
$ pg-copy-ch init --pg-host=pg-prod --pg-user=reader --pg-db=system
Reinitialized existing config in .pg-copy-ch/config

$ tail .pg-copy-ch/config
...
[table]
budgets   = "REPLACE"
creatives = "REPLACE"
orders    = "REPLACE"
schedules = "REPLACE"
```

### Copy

Once you setup config, you can run `copy` with specifying the table by one of '-a', '-t', '-f', '-F'.

```console
$ pg-copy-ch copy -t users,orders # Copy only the specified tables
$ pg-copy-ch copy -a              # Copy all tables in config
$ pg-copy-ch copy -f <ALLOW_FILE> # Copy all tables both in the config and in <ALLOW＿FILE>.
$ pg-copy-ch copy -F <DENY_FILE>  # Copy all tables in the config and NOT in <DENY_FILE>.
```

### Filter by allow

'-f <FILE>' obtains allow table names from the FILE, one per line.
These table names must exist in the **config:[table]** too.
In short, this works as `cat config:[table] | grep -f FILE` in unix.

```console
$ vi tables
users
orders

$ pg-copy-ch copy -f tables
```

It is same as

```console
$ pg-copy-ch copy -t users,orders
```

### Filter by deny

'-F <FILE>' skips table names written in the FILE.
This works as a regular expression if the line contains '^' or '$'.
For example, this will ignore all PostgreSQL system tables.

```console
$ vi ignores
^pg_

$ pg-copy-ch copy -F ignores
```

### Dryrun

'-n' just prints the actions that would be executed, but do not execute them.

```console
$ pg-copy-ch copy -t users,orders,xxx -n
Table  PostgreSQL Action
------ ---------- ----------------------------
users  FOUND      (will) Replace
orders FOUND      (will) Replace
xxx    N/A        Ignore (PG schema not found)
```

## Find performance killers

First, run with logging by `-l log`.

```console
$ pg-copy-ch -a -l log
```

Find worst record counts.

```console
$ grep REPLACED log | sort -n -k 5 -r | head -3
[05:28:26] (092/428) creatives    REPLACED 11989140 (37.01s)
[05:29:28] (157/428) constraints  REPLACED 5765600 (2.79s)
[05:31:15] (280/428) eviews       REPLACED 4460582 (5.67s)
```

Find worst time.
```console
$ grep REPLACED log | sort -n -t'(' -k 3 -r | head -3
[05:28:26] (092/428) creatives    REPLACED 11989140 (37.01s)
[05:26:38] (008/428) schedules    REPLACED 1115075 (22.90s)
[05:32:47] (343/428) statistics   REPLACED 2443266 (8.98s)
```

## Development

* using [Crystal](http://crystal-lang.org/) on docker

```console
$ make
```

## TODO: Test

Not implemented yet.

```
$ make test
```

## Contributing

1. Fork it (<https://github.com/maiha/pg-copy-ch/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [maiha](https://github.com/maiha) - creator and maintainer
