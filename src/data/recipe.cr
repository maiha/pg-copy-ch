abstract class Data::Recipe
  var table  : String
  var pg     : Pg::Meta
  var ch     : Ch::Meta
  var reason : String

  def initialize(@table, @pg = nil, @ch = nil, @reason = nil)
  end

  def to(klass : Recipe.class) : Recipe
    if control?
      self
    else
      klass.new(table, pg?)
#      Ignore.new(table)
    end
  end
  
  def action : String
    self.class.name.sub(/^.*::/, "")
  end

  def control? : Bool
    is_a?(Control)
  end

  abstract def color : Symbol

  def colorize(text)
    text.to_s.colorize(color)
  end

  def to_s(io : IO)
    io << action
    io << " (#{reason})" if reason?
  end

  def to_toml(maxsize : Int32? = nil) : String
    if n = maxsize
      "%-#{n}s = %s" % [table, to_s.inspect]
    else
      "%s = %s" % [table, to_s.inspect]
    end
  end

  def self.from_toml(table : String, setting) : Recipe
    case setting
    when "REPLACE"
      Replace.new(table)
    else
      raise ArgumentError.new("fatal: table setting is not supported: #{setting.inspect}")
    end
  end

  abstract class Control < Recipe
    var color : Symbol = :cyan
  end
  
  class Skip < Control
    var color : Symbol = :cyan
  end

  class Ignore < Control
    var color : Symbol = :yellow
  end

  class Count < Recipe
    var color : Symbol = :green
  end

  class GuardCount < Recipe
    var color : Symbol = :green
  end

  class Replace < Recipe
    var color : Symbol = :green
  end
end
