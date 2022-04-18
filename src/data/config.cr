class Data::Config < TOML::Config
  INFINITE = -1_i64

  var path   : String
  var dryrun : Bool
  var logger : Logger = Pretty::Logger.build_logger({"path" => "STDOUT", "name" => "(config)"})
  var table_recipes = Hash(String, Recipe).new

  str "postgres/host", pg_host
  i64 "postgres/port", pg_port
  str "postgres/user", pg_user
  str "postgres/db"  , pg_db
  str "postgres/psql", pg_psql
  i64 "postgres/ttl_meta"       , pg_ttl_meta
  i64 "postgres/ttl_data"       , pg_ttl_data
  i64 "postgres/ttl_count"      , pg_ttl_count
  i64 "postgres/max_record_size", pg_max_record_size
  str "postgres/before_sql"     , pg_before_sql
  bool "postgres/ignore_pg_catalog", pg_ignore_pg_catalog

  str "clickhouse/host", ch_host
  i64 "clickhouse/port", ch_port
  str "clickhouse/user", ch_user
  str "clickhouse/db"  , ch_db
  str "clickhouse/password", ch_password
  i64 "clickhouse/ttl_data"        , ch_ttl_data
  i64 "clickhouse/allow_errors_num", ch_allow_errors_num
  str "clickhouse/engine"          , ch_engine
  str "clickhouse/replace_query"   , ch_replace_query

  def initialize(toml, @dryrun, @logger = nil)
    super(toml)
  end

  def pg_psql : String
    pg_psql? || "psql -h %host -p %port -U %user %db -w"
  end

  def pg_ttl_meta : Int64
    pg_ttl_meta? || 86400_i64
  end

  def pg_ttl_data : Int64
    pg_ttl_data? || 3000_i64
  end

  def pg_ttl_count : Int64
    pg_ttl_count? || INFINITE
  end

  def pg_max_record_size : Int64
    pg_max_record_size? || INFINITE
  end

  def pg_before_sql : String
    before = pg_before_sql? || ""
    before = "#{before}".sub(/[;\s]+\Z/, "").strip
    before = "#{before};\n" if !before.empty?
    return before
  end

  def pg_ignore_pg_catalog : Bool
    v = pg_ignore_pg_catalog?
    return v.is_a?(Bool) ? v : true
  end

  def pg_client : Pg::Client
    Pg::Client.new(self)
  end

  delegate psql, to: pg_client

  def ch_ttl_data : Int64
    ch_ttl_data? || 3000_i64
  end

  def ch_client : Ch::Client
    Ch::Client.new(self)
  end

  delegate clickhouse_client, to: ch_client

  def resolve(tmpl : String, group : String)
    return tmpl if !tmpl.includes?('%')

    table = self.toml[group]?
    case table
    when Hash
      return tmpl.gsub(/%([a-zA-Z0-9_]+)/) { (table[$1]? || "%#{$1}").to_s }
    else
      raise ArgumentError.new("fatal: no tables named #{group.inspect} in config. (while resolving #{tmpl.inspect})")
    end
  end

  def dryrun(msg : String)
    if dryrun?
      raise Dryrun.new(msg)
    end
  end

  protected def not_found(key)
    case key
    when %r{^(.*?)/(.*)}
      name = "config:#{$2} [#{$1}]"
    else
      name = "config:#{key}"
    end
    raise NotFound.new("#{name} is not found")
  end

  def build_logger : Logger
    build_logger(self.toml["logger"]?)
  end

  def build_logger(v : Nil) : Logger
    Pretty::Logger.build_logger({"path" => "STDERR", "format" => "(no 'config[logger]') {{message}}"})
  end

  def build_logger(hash : Hash) : Logger
    hint = hash["name"]?.try{|s| "[#{s}]"} || ""
    hash["path"] || abort "fatal: config[logger].path is missing"
    logger = Pretty::Logger.build_logger(hash)
    return logger
  end

  def build_logger(ary : Array) : Logger
    Pretty::Logger.new(ary.map{|i| build_logger(i).as(Logger)})
  end

  def build_logger(v) : NoReturn
    raise "fatal: config[logger] type error (#{v.class})"
  end

  def to_toml : String
    <<-EOF
      [postgres]
      host = #{pg_host.inspect}
      port = #{pg_port.inspect}
      user = #{pg_user.inspect}
      db   = #{pg_db.inspect}
      psql = "psql -q -h %host -p %port -U %user %db -w"
      # psql = "PGPASSWORD=foo psql -q -h %host -p %port -U %user %db -w"
      # psql = "psql -q -h %host -p %port -U %user %db -w --dbname=postgres --set=sslmode=require --set=sslrootcert=./sslcert.crt"
      ttl_meta        = #{pg_ttl_meta.inspect}
      ttl_data        = #{pg_ttl_data.inspect}
      ttl_count       = #{pg_ttl_count.inspect}
      max_record_size = #{pg_max_record_size.inspect}
      # before_sql      = "SET search_path to myschema,public;"
      ignore_pg_catalog = true

      [clickhouse]
      host = #{ch_host.inspect}
      port = #{ch_port.inspect}
      user = #{ch_user.inspect}
      db   = #{ch_db.inspect}
      password   = #{ch_password.inspect}
      ttl_data         = #{ch_ttl_data.inspect}
      engine           = "Log"
      allow_errors_num = 3
      replace_query    = """
      CREATE TABLE IF NOT EXISTS {{table}} AS {{table}}_new;
      DROP TABLE IF EXISTS {{table}}_old;
      RENAME TABLE {{table}} TO {{table}}_old, {{table}}_new TO {{table}};
      DROP TABLE IF EXISTS {{table}}_old;
      """

      # format: https://github.com/maiha/composite_logger.cr#available-keywords
      [[logger]]
      path     = "STDOUT"
      level    = "INFO"
      format   = "[{{time=%H:%M:%S}}] {{message}}"
      colorize = true
      EOF
  end

  def self.from(cmd : Cmds::Cmd) : Config
    toml = TOML.parse("")
    config = Config.new(toml, dryrun: cmd.dryrun, logger: cmd.logger)
    config.path = cmd.current_config_path

    # postgres
    config["postgres/host"] = cmd.pg_host
    config["postgres/port"] = cmd.pg_port
    config["postgres/user"] = cmd.pg_user
    config["postgres/db"  ] = cmd.pg_db

    # clickhouse
    config["clickhouse/host"] = cmd.ch_host
    config["clickhouse/port"] = cmd.ch_port
    config["clickhouse/user"] = cmd.ch_user
    config["clickhouse/db"  ] = cmd.ch_db
    config["clickhouse/password"  ] = cmd.ch_password

    return config
  end

  def self.load(path : String, dryrun : Bool, logger : Logger) : Config
    toml = TOML.parse_file(path)
    config = new(toml, dryrun: dryrun, logger: logger)
    config.path = path
    return config
  end
end
