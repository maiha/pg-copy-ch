# stdlib
require "option_parser"
require "json"

# shards
require "var"
require "try"
require "cmds"
require "toml-config"
require "clickhouse"
require "pretty"
require "shell"
require "shard"

# apps
require "./ext/**"
require "./data/**"
require "./core/**"
require "./cmds/**"

class Main < Cmds::Cli::Default
  include Core

  def run(args)
    case args[0]?
    when "-h", "--help"
      help_and_exit!
    when "-V", "--version"
      STDOUT.puts Shard.git_description
    else
      super(args)
    end
  rescue err
    STDERR.puts err.to_s.chomp.colorize(:red)
    exit 100
  end  
end

Main.run
