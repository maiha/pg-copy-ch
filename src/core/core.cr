module Core
  var parser : OptionParser = build_parser
  var program : String = "pg-copy-ch"

  # global options
  var workdir     : String = ".pg-copy-ch"
  var debug       : Bool   = false
  var dryrun      : Bool   = false
  var verbose     : Bool   = false
  var config_path : String
  var logger_path : String

  # config
  var config : Data::Config = load_config

  # table
  var tables_all : Bool = false
  var tables_include_from : String
  var tables_exclude_from : String
  var tables_fixed : Array(String)

  # pg
  var pg_host : String = "localhost"
  var pg_port : Int64  = 5432_i64
  var pg_user : String = "postgres"
  var pg_db   : String = "postgres"
  var pg_ttl  : Int64  = 1.hour.total_seconds.to_i64
  var pg_ignore_regex : Regex = /^pg_/

  # ch
  var ch_host : String = "localhost"
  var ch_port : Int64  = 9000_i64
  var ch_user : String = "default"
  var ch_db   : String = "default"

  def before
    parser.parse(args)
    if v = logger_path?
      @logger = Pretty::Logger.build_logger({"path" => (v == "-") ? "STDOUT" : v})
    else
      @logger = Pretty::Logger.build_logger({"format" => "{{message}}"})
    end
    if debug
      logger.level = "DEBUG"
    end
  end

  def current_config_path
    config_path? || File.join(workdir, "config")
  end

  protected def load_config : Data::Config
    path = current_config_path
    File.exists?(path) || abort "fatal: config not found: #{path.inspect}\nRun '#{program} init' first."
    return Data::Config.load(path: path, logger: logger)
  end

  protected def load_tables_from(path : String) : Array(String)
    tables = Array(String).new
    File.read_lines(path).each_with_index do |line, i|
      case line
      when /^\s*$/                 # ignore
      when /^\s*#/                 # ignore
      when /^(\S+)\s*($|#)/ # ok
        tables << $1
      else
        abort "fatal: unexpected table name found #{line.inspect} in #{path}:#{i+1}"
      end
    end
    return tables
  end

  protected def build_parser
    parser = OptionParser.new
    setup_parser(parser)
    return parser
  end

  def setup_parser(parser)
    if is_a?(Cmds::Cmd)
      parser.banner = "usage: #{program} [option] #{self.class.cmd_name} <task> [args]"
    else
      parser.banner = "usage: #{program} [option] <command> <task> [args]"
    end

    parser.on("-a", "--all", "Process all tables") { self.tables_all = true }
    parser.on("-t", "--tables TABLE,...", "Process these tables") {|v| self.tables_fixed = v.strip.split(/,/).map(&.strip.presence).compact }
    parser.on("-f", "--include-from FILE", "Process tables written in FILE, one per line") {|v| self.tables_include_from = v.presence }
    parser.on("-F", "--exclude-from FILE", "Process all tables without in FILE, one per line") {|v| self.tables_exclude_from = v.presence }
    parser.on("--pg-host HOST", "PostgreSQL server host (default: #{pg_host})") {|v| self.pg_host = v.presence }
    parser.on("--pg-port PORT", "PostgreSQL server port (default: #{pg_port})") {|v| self.pg_port = v.to_i64? || abort "pg_port expects int, but got #{v.inspect}" }
    parser.on("--pg-user USER", "PostgreSQL server user (default: #{pg_user})") {|v| self.pg_user = v.presence }
    parser.on("--pg-db DB"    , "PostgreSQL server db   (default: #{pg_db})") {|v| self.pg_db = v.presence }
    parser.on("--pg-ignore REGEX", "PostgreSQL ignore tables (default: #{pg_ignore_regex})") {|v| self.pg_ignore_regex = Regex.new(v) }
    parser.on("--ch-host HOST", "ClickHouse server host (default: #{ch_host})") {|v| self.ch_host = v.presence }
    parser.on("--ch-port PORT", "ClickHouse server port (default: #{ch_port})") {|v| self.ch_port = v.to_i64? || abort "ch_port expects int, but got #{v.inspect}" }
    parser.on("--ch-user USER", "ClickHouse server user (default: #{ch_user})") {|v| self.ch_user = v.presence }
    parser.on("--ch-db DB"    , "ClickHouse server db   (default: #{ch_db})") {|v| self.ch_db = v.presence }
    parser.on("-w", "--workdir <WORKDIR>", "Directory where files created (default: #{workdir})") {|v| self.workdir = v.presence }
    parser.on("-c", "--config FILE", "Config file (default: #{current_config_path})") {|v| self.config_path = v.presence }
    parser.on("-l", "--log FILE", "Logging file name (default: STDOUT)") {|v| self.logger_path = v }
    parser.on("-d", "--debug", "Turn on debug message") {|v| self.debug = true }

    parser.on("-n", "--dryrun", "Dryrun mode") { self.dryrun = true }
    parser.on("-v", "--verbose", "Verbose mode") { self.verbose = true }
    parser.on("-h", "--help", "Show this help") { help_and_exit! }
  end

  protected def help_and_exit!
    puts parser
    examples = usages_for_cmd
    if examples.any?
      puts "\nexamples:"
      puts Pretty.lines(examples, indent: "    ", delimiter: " ")
    end
    if is_a?(Cmds::Cmd) && self.class.task_names.any?
      puts "\ntasks:\n  %s" % self.class.task_names.join(", ")
    end
    exit 0
  end
end
