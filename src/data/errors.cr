class Dryrun < Exception
  var cmd : String
  def initialize(@cmd)
    super(cmd)
  end
end
