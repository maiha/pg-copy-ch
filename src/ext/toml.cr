require "toml"

######################################################################
### to_toml

# alias Type = Bool | Int64 | Float64 | String | Time | Array(Type) | Hash(String, Type)

# Bool | Int64 | Float64 | String
class Object
  def to_toml : String
    to_s
  end
end

class String
  def to_toml : String
    inspect
  end
end

class Array
  def to_toml : String
    "[%s]" % map{|v| v.to_toml}.join(", ")
  end
end

class Hash(K,V)
  def to_toml : String
    return "" if empty?

    String.build do |s|
      maxsize = keys.map{|v| Pretty.string_width(v)}.max
      each do |key, val|
        case val
        when Hash
          s.puts "[%s]" % key
          s.puts val.to_toml
        else
          s.puts "%-#{maxsize}s = %s" % [key, val.to_toml]
        end
      end
    end
  end
end
