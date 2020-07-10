Cmds.command "init" do
  include Core

  var config_required : Bool = false

  task "config" do
    path = current_config_path
    msg  = File.exists?(path) ? "Reinitialized existing config" : "Initialized empty config"
    @config = Data::Config.from(self)

    config.dryrun(msg)
    Pretty::File.write(path, config.to_toml)
    logger.info "#{msg} in #{path}"
  end

  task "tables" do
    path = File.join(workdir, "tables")
    data = config.pg_client.metas.keys.sort.join("\n")
    msg  = "Created #{path}"

    config.dryrun(msg)
    Pretty::File.write(path, data)
    logger.info msg
  end
end
