class Data::Ch::Client
  var config : Data::Config
  var workdir : String

  delegate logger, dryrun, to: config
  delegate ch_host, ch_port, ch_user, ch_db, ch_password, ch_password?, ch_ttl, to: config

  def initialize(@config)
  end

  protected def client
    Clickhouse.new(host: ch_host, user: ch_user, database: ch_db, password: ch_password?)
  end

  def metas : Hash(String, Meta)
    metas = Hash(String, Meta).new
    res = client.execute <<-EOF
      SELECT
        name,
        metadata_modification_time
      FROM system.tables
      WHERE database = '#{ch_db}'
      EOF
    res.success!.map(String, Time).each do |(table, mtime)|
      metas[table] = Meta.new(table, mtime)
    end
    logger.debug "ch: fetched %d table information" % metas.size
    return metas
  end

  def clickhouse_client(cmd : String)
    shell = Shell::Seq.new(abort_on_error: true)

    if ch_password?
      shell.run!("clickhouse-client -h '#{ch_host}' --port #{ch_port} -u '#{ch_user}' --password '#{ch_password}' -d '#{ch_db}' #{cmd}")
    else
      shell.run!("clickhouse-client -h '#{ch_host}' --port #{ch_port} -u '#{ch_user}' -d '#{ch_db}' #{cmd}")
    end
  end
end
