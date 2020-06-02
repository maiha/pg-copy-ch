class Data::Pg::Column
  var num         : Int32
  var name        : String
  var type        : String
  var not_null    : Bool
  var primary_key : Bool

  def initialize(@num, @name, @type, @not_null, @primary_key)
  end

  def bool? : Bool
    !! (type =~ /^bool/)
  end

  def timestamp?
    !! (type =~ /^timestamp/)
  end

  def to_clickhouse : Clickhouse::Column
    ch_type = Pg::Type.clickhouse_type(type)
    ch_type = "Nullable(#{ch_type})" if !not_null
    Clickhouse::Column.new(name, ch_type)
  end
    
  def to_s(io : IO)
    io << "#{name} #{type}"
    io << " NOT NULL" if not_null
  end
end
