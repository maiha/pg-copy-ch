module Core
  protected def time(&block)
    t1 = Pretty.now
    block.call
    return Pretty.now - t1
  end
end
