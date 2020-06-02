module Data::Pg::Type
  def self.clickhouse_type(pg_type : String) : String
    case pg_type
    when "bool", "boolean"
      "UInt8"
    when "date"
      "Date"
    when "float4", "real"
      "Float32"
    when "float8", "double precision"
      "Float64"
    when "int2", "int4", "integer", "smallint"
      "Int32"
    when "int8", "bigint"
      "Int64"
    when "text", "varchar", "bytea", "jsonb"
      "String"
    when /character varying/
      "String"
    when /timestamp/            # timestamp without time zone
      "DateTime"
    else
      raise "not supported yet: pg_type[#{pg_type.inspect}]"
    end
  end
end
