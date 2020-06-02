class Data::Config < TOML::Config
  INFINITE = -1_i64

  var path : String
  var logger : Logger = Logger.new(STDOUT)
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
  
  def initialize(toml, @logger = nil)
    super(toml)
    build_recipes!
  end
  
  def build_recipes!
    case v = self["table"]?
    when Nil
      # nop
    when Hash
      v.each do |table, setting|
        table_recipes[table] = Recipe.from_toml(table, setting)
      end
    else
      logger.warn "warn: config:[table] expected Hash, but got #{v.class} (IGNORED)"
    end
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

  def to_toml : String
    String.build do |s|
      s.puts "[postgres]"
      s.puts "host = %s" % pg_host.inspect
      s.puts "port = %s" % pg_port.inspect
      s.puts "user = %s" % pg_user.inspect
      s.puts "db   = %s" % pg_db.inspect
      s.puts "ttl_meta        = %s" % pg_ttl_meta.inspect
      s.puts "ttl_data        = %s" % pg_ttl_data.inspect
      s.puts "ttl_count       = %s" % pg_ttl_count.inspect
      s.puts "max_record_size = %s" % pg_max_record_size.inspect
      s.puts
      s.puts "[clickhouse]"
      s.puts "host = %s" % ch_host.inspect
      s.puts "port = %s" % ch_port.inspect
      s.puts "user = %s" % ch_user.inspect
      s.puts "db   = %s" % ch_db.inspect
      s.puts "ttl_data         = %s" % ch_ttl_data.inspect
      s.puts "allow_errors_num = %s" % (ch_allow_errors_num? || 3)
      s.puts
      s.puts "[table]"
      if table_recipes.any?
        maxsize = table_recipes.keys.map(&.size).max
        table_recipes.each do |table, recipe|
          s.puts recipe.to_toml(maxsize: maxsize)
        end        
      end
    end
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
