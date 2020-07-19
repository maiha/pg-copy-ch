# pg-copy-ch [![Build Status](https://travis-ci.org/maiha/pg-copy-ch.svg?branch=master)](https://travis-ci.org/maiha/pg-copy-ch)

Simply copy the current PostgreSQL data to ClickHouse
* Simple    : Just dumps and imports, so it works with older versions like 9.x.
* Handy     : Static single binary, so you can install it just by wget or cp.
* Automatic : Create ClickHouse tables from PostgreSQL automatically.
* Easy      : Include/Exclude tables by regex. Skip by max data count, ttl.

```console
$ psql mydb -c "SELECT count(*) FROM users"             # => 3835
$ clickhouse-client -q "CREATE DATABASE pg"

$ pg-copy-ch init config --pg-db=mydb --ch-db=pg
$ pg-copy-ch copy -t users
[09:05:28] (1/1) users REPLACED 3835 (0.35s)

$ clickhouse-client -q "SELECT count(*) FROM pg.users"  # => 3835
```

## Installation
* **psql** : required for PostgreSQL client
* **clickhouse-client** : required for ClickHouse client
* x86_64 static binary: https://github.com/maiha/pg-copy-ch/releases

```console
$ wget https://github.com/maiha/pg-copy-ch/releases/latest/download/pg-copy-ch
```

## Usage

### config

First, create config file by `init config`.

```console
$ pg-copy-ch init config
Initialized empty config in .pg-copy-ch/config
```

Then, edit `config` file about connection settings for PostgreSQL and ClickHouse.

```console
$ vi .pg-copy-ch/config
[postgres]
host = "pg-server1"
port = 5432
user = "postgres"
db   = "mydb"
psql = "psql -h %host -p %port -U %user %db -w"
...
```

### Copy

Once you setup config, you can run `copy` with specifying the table by one of '-a', '-t', '-f', '-F'.

```console
$ pg-copy-ch copy -t users,orders # Copy only the specified tables
$ pg-copy-ch copy -a              # Copy all tables
$ pg-copy-ch copy -f <ALLOW_FILE> # Copy all tables both in the config and in <ALLOW＿FILE>.
$ pg-copy-ch copy -F <DENY_FILE>  # Copy all tables in the config and NOT in <DENY_FILE>.
```

### Filter by allow

'-f <FILE>' obtains allow table names from the FILE, one per line.
We can create it by the `init tables` command.

```console
$ pg-copy-ch init tables
Created .pg-copy-ch/tables
```

Then, edit or comment out as you like.

```console
$ vi .pg-copy-ch/tables
# budgets
creatives
orders
...

$ pg-copy-ch copy -f .pg-copy-ch/tables
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

First, run and generate log.

```console
$ pg-copy-ch -a | tee log
```

##### worst record counts

```console
$ grep REPLACED log | sort -n -k 5 -r | head -3
[05:28:26] (092/428) creatives    REPLACED 11989140 (37.01s)
[05:29:28] (157/428) constraints  REPLACED 5765600 (2.79s)
[05:31:15] (280/428) eviews       REPLACED 4460582 (5.67s)
```

##### worst time

```console
$ grep REPLACED log | sort -n -t'(' -k 3 -r | head -3
[05:28:26] (092/428) creatives    REPLACED 11989140 (37.01s)
[05:26:38] (008/428) schedules    REPLACED 1115075 (22.90s)
[05:32:47] (343/428) statistics   REPLACED 2443266 (8.98s)
```

## PostgreSQL

### psql

For example, if you want to use SSL, you can specify the command directly to `psql` in config.
Here, '%' prefixed words are replaced by those settings automatically.

```toml
[postgres]
psql = "psql -h %host -p %port -U %user %db -w --dbname=postgres --set=sslmode=require --set=sslrootcert=./sslcert.crt"
```

### authorization

Using `~/.pgpass` is a easiest way to specify a password.

If it is difficult to write to HOME by cron execution, you can embed it directly into the config file using `psql` above.

```toml
[postgres]
psql = "PGPASSWORD=foo psql -h %host -p %port -U %user %db -w"
```

## Development

* using [Crystal](http://crystal-lang.org/) on docker

```console
$ make
```

## Test

```
$ make ci
```

## Contributing

1. Fork it (<https://github.com/maiha/pg-copy-ch/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [maiha](https://github.com/maiha) - creator and maintainer
