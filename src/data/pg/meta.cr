class Data::Pg::Meta
  var table : String
  var columns = Array(Column).new

  def initialize(@table, @columns = nil)
  end

  def data_sql(pg_before_sql : String) : String
    column = columns.map{|c|
      quoted = %Q|"#{c.name}"|
      case c
      when .bool?
        "CAST(#{quoted} AS int) AS #{quoted}"
      when .timestamp?
        "date_trunc('second',#{quoted}) AS #{quoted}"
      else
        quoted
      end
    }.join(",")

    "#{pg_before_sql}Copy (Select #{column} From #{table}) To STDOUT With (FORMAT CSV, HEADER TRUE, DELIMITER ',', FORCE_QUOTE *)"
  end
  
  def to_clickhouse : Clickhouse::Schema::Create
    ch = Clickhouse::Schema::Create.new
    ch.table = table
    ch.engine = "Log"
    columns.each do |c|
      ch.columns << c.to_clickhouse
    end
    ch
  end
    
  def to_s(io : IO)
    io << "CREATE TABLE #{table}("
    io << columns.map{|c| c.to_s}.join(", ")
    io << ")"
  end
end

class Data::Pg::Meta
  class ParseError < Exception
  end

  def self.from_csv(buf : String) : Hash(String, Meta)
    grouped_metas = Hash(String, Meta).new
    
    clue = "parsing csv"
    rows = CSV.parse(buf)
    rows.each_with_index do |row, i|
      clue = "line #{i+1}"

      row.size == 6 || raise "CSV expected 6 fields, but got #{row.size} fields"
      # ```
      # table | num |   name   |            type             | notnull | primary_key
      # ------+-----+----------+-----------------------------+---------+-------------
      # users |   1 | id       | bigint                      |       1 |           1
      # users |   2 | name     | character varying(255)      |       0 |           0
      # ```
      table = row[0].presence || raise "field1 must be present"
      num   = row[1].to_i?    || raise "field2 must be a number"
      name  = row[2].presence || raise "field3 must be present"
      type  = row[3].presence || raise "field4 must be present"
      nnull = (row[4].to_i?   || raise "field5 must be a number") == 1
      pkey  = (row[5].to_i?   || raise "field6 must be a number") == 1

      meta = grouped_metas[table] ||= Meta.new(table)
      meta.columns << Column.new(num, name, type, nnull, pkey)
    end
    
    return grouped_metas
  rescue err
    raise ParseError.new("#{clue}: #{err}")
  end
  
  def self.query(table : String? = nil, ignore_pg_catalog : Bool = false) : String
    String.build do |s|
      and_ignore_pg_catalog = "AND nsp.nspname <> 'pg_catalog'" if ignore_pg_catalog
      and_filter_by_table   = "AND pgc.relname = '#{table}'"    if table

      s.puts <<-EOF
        SELECT DISTINCT
            pgc.relname as table,
            a.attnum as num,
            a.attname as name,
            format_type(a.atttypid, a.atttypmod) as type,
            a.attnotnull::int as notnull, 
            coalesce(i.indisprimary,false)::int as primary_key
        FROM pg_attribute a 
        JOIN pg_class pgc ON
            (pgc.oid = a.attrelid AND pgc.relkind = 'r')
        LEFT JOIN pg_index i ON 
            (pgc.oid = i.indrelid AND i.indkey[0] = a.attnum)
        LEFT JOIN pg_description com ON 
            (pgc.oid = com.objoid AND a.attnum = com.objsubid)
        LEFT JOIN pg_attrdef def ON 
            (a.attrelid = def.adrelid AND a.attnum = def.adnum)
        LEFT JOIN pg_namespace nsp ON 
            (pgc.relnamespace = nsp.oid)
        WHERE a.attnum > 0 AND pgc.oid = a.attrelid
          AND pg_table_is_visible(pgc.oid)
          AND NOT a.attisdropped
          #{and_ignore_pg_catalog}
          #{and_filter_by_table}
        ORDER BY "table", a.attnum
        EOF
    end
  end
end
