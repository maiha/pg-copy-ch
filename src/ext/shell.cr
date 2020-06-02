require "shell"

class Shell
  getter args

  def fail
    raise "exit %s: %s\n%s" % [exit_code, cmd, stderr]
  end
end
