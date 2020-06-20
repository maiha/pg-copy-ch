require "pretty"

class Pretty::Logger
  def initialize(loggers : Array(::Logger)? = nil, memory : Logger::Severity | String | Nil = nil)
    @loggers = loggers || Array(::Logger).new
    if memory
      @memory = IO::Memory.new
      @loggers << ::Logger.new(@memory).tap(&.level = memory)
    end
    super(nil)
  end
end
