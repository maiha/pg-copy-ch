module Core
  protected def usages_for_cmd : Array(Array(String))
    usages = Array(Array(String)).new
    Cmds::CMDS.each do |name, klass|
      next if is_a?(Cmds::Cmd) && self.class.cmd_name != name
      klass.usages.each do |usage|
        args = usage.text.split(/\s*#\s*/, 2)
        args = (args.size == 2) ? [args[0], "# #{args[1]}"] : [usage.text, ""]
        usages << [program, name] + args
      end
    end
    return usages
  end

  protected def usages_for_task : Array(Array(String))
    usages = Array(Array(String)).new
    return usages if !is_a?(Cmds::Cmd)
    Cmds::CMDS.each do |name, klass|
      next if self.class.cmd_name != name
      klass.usages.each do |usage|
        args = usage.text.split(/\s*#\s*/, 2)
        args = (args.size == 2) ? [args[0], "# #{args[1]}"] : [usage.text, ""]
        usages << [program, name] + args
      end
    end
    return usages
  end
end
