class Data::Pg::Client
  var config : Data::Config
  var workdir : String

  private var meta_sql_path : String
  private var meta_csv_path : String

  delegate logger, dryrun, to: config
  delegate pg_ttl_meta, to: config
  delegate pg_before_sql, to: config
  delegate pg_ignore_pg_catalog, to: config

  def initialize(@config)
    @workdir = File.dirname(config.path)
    @meta_sql_path = "#{workdir}/pg/meta.sql"
    @meta_csv_path = "#{workdir}/pg/meta.csv"
  end

  # ignore_dryrun: ignore dryrun for the case of "copy -n"
  def metas(ignore_dryrun : Bool = false) : Hash(String, Meta)
    metas = Meta.from_csv(fetch_meta_csv(ignore_dryrun: ignore_dryrun))
    logger.debug "pg: fetched %d schema from PostgreSQL" % metas.size
    return metas
  end

  private def fetch_meta_csv(ignore_dryrun : Bool) : String
    sql = meta_sql_path
    csv = meta_csv_path

    if File.exists?(csv)
      mtime_csv    = Pretty::File.mtime(csv)
      mtime_config = Pretty::File.mtime(config.path)

      # check mtimes between config and csv
      config_unchanged = (mtime_config <= mtime_csv)
      csv_not_expired  = (Pretty.now - mtime_csv < pg_ttl_meta.seconds)

      if config_unchanged && csv_not_expired
        logger.debug "pg: (cached) #{csv}"
        return File.read(csv)
      end
    end

    main   = Meta.query(ignore_pg_catalog: pg_ignore_pg_catalog).gsub(/^/m, "    ")
    data   = "%sCopy (\n%s) To STDOUT With CSV DELIMITER ','" % [pg_before_sql, main]
    Pretty::File.write(sql, data)
    logger.debug "pg: created #{sql}"

    psql("-f #{sql} | sed -e 's/^public\.//' > #{csv}.tmp", ignore_dryrun: ignore_dryrun)
    Pretty::File.mv("#{csv}.tmp", csv)

    return File.read(csv)
  end

  def psql(arg : String, ignore_dryrun : Bool = false)
    psql = config.resolve(config.pg_psql, group: "postgres")
    cmd  = "#{psql} #{arg}"

    dryrun(cmd) if !ignore_dryrun
    shell = Shell::Seq.new(abort_on_error: true)
    logger.debug "pg: #{cmd}"
    shell.run!(cmd)
    shell.stderr.empty? || raise shell.stderr
  end
end
