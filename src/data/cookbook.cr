require "./recipe"

class Data::Cookbook  
  include Enumerable(Recipe)
  delegate each, to: recipes

  var recipes : Array(Recipe)
  var config  : Config
  var workdir : String
  var logger  : Logger = Pretty::Logger.build_logger({"path" => "STDOUT", "name" => "(cookbook)"})
  var cooked  = Array(Chef::Cooked).new

  def initialize(@recipes, @config, @workdir, @logger)
    pg_metas = config.pg_client.metas
    ch_metas = config.ch_client.metas

    @recipes = recipes.map{|r|
      pg = pg_metas[r.table]?
      ch = ch_metas[r.table]?
      nr = if !r.control? && !pg
             Recipe::Ignore.new(r.table, reason: "PG schema not found")
           else
             r
           end
      nr.pg = pg
      nr.ch = ch
      nr
    }
  end

  def to(klass : Recipe.class) : Cookbook
    Cookbook.new(recipes.map(&.to(klass)), config, workdir, logger)
  end
  
  def execute
    max = map(&.table.size).max
    each_with_index do |recipe, i|
      label = table_label(i+1, max, recipe.table)
      dir   = "#{workdir}/copying/#{recipe.table}"
      Pretty::File.mkdir_p(dir)
      Dir.cd(dir) do
        chef  = Chef.new(recipe, config, label: label, logger: logger)
        # span = time { chef.cook }
        cooked << chef.cook
        #logger.info "#{hint} COUNT (%.1fs)" % span.total_seconds
      end
    end
  end

  def cooked_summary : String
    grouped = cooked.group_by(&.class.to_s)
    keys = {{ Data::Chef::Cooked.subclasses.map(&.stringify) }}
    results = keys.map{|key|
      if ary = grouped[key]?
        "%s:%d" % [key.sub(/^.*::/,"").downcase, ary.size]
      else
        nil
      end
    }.compact
    results.join(", ")
  end

  private def table_label(n, max, table)
    w = size.to_s.size
    "(%0#{w}d/%0#{w}d) %-#{max}s" % [n, size, table]
  end

  def plan(verbose : Bool, bytes : Int32) : String
    lines = map{|recipe|
      name = recipe.colorize(recipe.table)
      pg   = recipe.pg? ? "FOUND".colorize(:green) : "N/A".colorize(:red)
      plan = recipe.colorize(recipe.control? ? recipe : "(will) #{recipe}")
      [name, pg, plan].map(&.to_s)
    }
    headers = %w( Table PostgreSQL Action )
    return Pretty.lines(lines, headers: headers, delimiter: " ").chomp
  end
end
