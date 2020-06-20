class Data::Config < TOML::Config
  INFINITE = -1_i64

  var path : String
  var logger : Logger = Pretty::Logger.build_logger({"path" => "STDOUT", "name" => "(config)"})
  var table_recipes = Hash(String, Recipe).new

  str "postgres/host", pg_host
  i64 "postgres/port", pg_port
  str "postgres/user", pg_user
  str "postgres/db"  , pg_db
  i64 "postgres/ttl_meta"       , pg_ttl_meta
  i64 "postgres/ttl_data"       , pg_ttl_data
  i64 "postgres/ttl_count"      , pg_ttl_count
  i64 "postgres/max_record_size", pg_max_record_size

  str "clickhouse/host", ch_host
  i64 "clickhouse/port", ch_port
  str "clickhouse/user", ch_user
  str "clickhouse/db"  , ch_db
  i64 "clickhouse/ttl_data"        , ch_ttl_data
  i64 "clickhouse/allow_errors_num", ch_allow_errors_num
  str "clickhouse/engine"          , ch_engine
  str "clickhouse/replace_query"   , ch_replace_query
  
  def initialize(toml, @logger = nil)
    super(toml)
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
      ttl_meta        = #{pg_ttl_meta.inspect}
      ttl_data        = #{pg_ttl_data.inspect}
      ttl_count       = #{pg_ttl_count.inspect}
      max_record_size = #{pg_max_record_size.inspect}

      [clickhouse]
      host = #{ch_host.inspect}
      port = #{ch_port.inspect}
      user = #{ch_user.inspect}
      db   = #{ch_db.inspect}
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
    config = Config.new(toml, logger: cmd.logger)
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

    return config
  end

  def self.load(path : String, logger : Logger) : Config
    toml = TOML.parse_file(path)
    config = new(toml, logger: logger)
    config.path = path
    return config
  end
end
