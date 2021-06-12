# stdlib
require "option_parser"
require "json"

# shards
require "logger"
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
      cmd = Cmds.cmd_table.resolve(args.shift?)
      cmd.run(args)
    end
  rescue dryrun : Dryrun
    STDOUT.puts "(dryrun) #{dryrun}".colorize(:yellow)
  rescue err
    handle_error(cmd, err)
  end  
end

Main.run
