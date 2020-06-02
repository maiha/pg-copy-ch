Cmds.command "init" do
  include Core

  usage "# Create a config file"
  
  def run
    path = current_config_path
    msg  = File.exists?(path) ? "Reinitialized existing config" : "Initialized empty cofig"

    config = Data::Config.from(self)
    config.pg_client.metas.each do |table, meta|
      case table
      when pg_ignore_regex
        logger.debug "ignore: #{table} (by --pg-ignore=#{pg_ignore_regex})"
      else
        config.table_recipes[table] = Data::Recipe::Replace.new(table)
      end
    end

    Pretty::File.write(path, config.to_toml)
    logger.info "#{msg} in #{path}"
  end
end
