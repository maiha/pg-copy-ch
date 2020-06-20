class Data::Pg::Client
  var config : Data::Config
  var workdir : String

  private var meta_sql_path : String
  private var meta_csv_path : String

  delegate logger, to: config
  delegate pg_host, pg_port, pg_user, pg_db, pg_ttl_meta, to: config

  def initialize(@config)
    @workdir = File.dirname(config.path)
    @meta_sql_path = "#{workdir}/pg_meta.sql"
    @meta_csv_path = "#{workdir}/pg_meta.csv"
  end

  def metas : Hash(String, Meta)
    metas = Meta.from_csv(fetch_meta_csv)
    logger.debug "pg: fetched %d schema from PostgreSQL" % metas.size
    return metas
  end

  private def fetch_meta_csv : String
    sql = meta_sql_path
    csv = meta_csv_path

    if File.exists?(csv)
      mtime = Pretty::File.mtime(csv)
      if Pretty.now - mtime < pg_ttl_meta.seconds
        logger.debug "pg: (cached) #{csv}"
        return File.read(csv)
      end
    end
    
    data = "Copy (%s) To STDOUT With CSV DELIMITER ','" % Meta.query
    Pretty::File.write(sql, data)
    logger.debug "pg: created #{sql}"

    psql("-f #{sql} #{pg_db} > #{csv}.tmp")
    Pretty::File.mv("#{csv}.tmp", csv)

    return File.read(csv)
  end

  def psql(cmd : String)
    shell = Shell::Seq.new(abort_on_error: true)
    shell.run!("psql -h '#{pg_host}' -p #{pg_port} -U '#{pg_user}' -w #{cmd}")
    shell.stderr.empty? || raise shell.stderr
  end
end
