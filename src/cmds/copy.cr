Cmds.command "copy" do
  include Core

  usage "-t users,orders # Copy only the specified tables"
  usage "-a              # Copy all tables in config"
  usage "-f <ALLOW_FILE> # Copy all tables both in the config and in <ALLOW＿FILE>."
  usage "-F <DENY_FILE>  # Copy all tables in the config and NOT in <DENY_FILE>."

  private var cookbook : Data::Cookbook = build_cookbook

  task "count" do
    @cookbook = cookbook.to(Data::Recipe::Count)
    execute
  end
  
  def run
    return super if args.any?
    execute
  end

  protected def execute
    if dryrun
      do_dryrun
    else
      cookbook.execute
      logger.info cookbook.cooked_summary
    end
  end

  private def sec_from(time : Time, precision : Int32? = 1) : String
    sec = (Pretty.now - time).total_seconds
    if precision
      return "%.#{precision}f" % sec
    else
      return sec.to_s
    end
  end

  private def cook(recipe, target = nil)
    tbl = recipe.table
    dir = "#{workdir}/tables/#{tbl}"
    Pretty::File.mkdir_p(dir)

    Dir.cd(dir) do
      t1 = Pretty.now
      v  = yield tbl
      t2 = Pretty.now

      # write operation result into json
      if target
        json = {
          "table" => tbl,
          "target" => target,
          "sec" => (t2 - t1).total_seconds,
        }.to_json
        File.write("#{target}.json", json)
      end
      return v
    end
  end

  private def cooked(recipe)
    tbl = recipe.table
    Dir.cd(dir) { yield }
  end
  
  private def check_data_count(recipe, hint)
    try = read_data_count(recipe)
    logger.debug "#{hint} check_data_count : %s" % (try.get? || "N/A")
    if count = try.get?
      if pg_max_record_size < count
        raise SKIP.new("SKIP (count is too large: #{count})")
      end
    end
  end

  protected def do_dryrun
    puts cookbook.plan(verbose: verbose, bytes: 200)
  end

  private def build_cookbook
    recipes = current_recipes
    recipes.any? || abort "No table settings are found. Please edit 'config:[table]'"
    cookbook = Data::Cookbook.new(recipes, config, workdir, logger)
    return cookbook
  end

  protected def current_recipes : Array(Data::Recipe)
    op_cnt = 0
    op_cnt +=1 if tables_all
    op_cnt +=1 if tables_include_from?
    op_cnt +=1 if tables_exclude_from?
    op_cnt +=1 if tables_fixed?

    case op_cnt
    when 0
      usage = Pretty.lines(usages_for_task, indent: "  ", delimiter: " ")
      abort "Please specify target tables by '-a', '-t', '-f', '-F'.\n#{usage}"
    when 1
      table_recipes = Hash(String, Data::Recipe).new
      config.pg_client.metas.each do |table, meta|
        table_recipes[table] = Data::Recipe::Replace.new(table)
      end
      
      # if tables_all # NOP
      if tables_include_from?
        regexs = load_tables_from(tables_include_from).map{|v| compile_regex_or_string(v)}
        table_recipes.keys.each do |table|
          unless regexs.any?{|r| r === table}
            table_recipes[table] = Data::Recipe::Skip.new(table, reason: "removed by -f")
          end
        end
      end
      if tables_exclude_from?
        regexs = load_tables_from(tables_exclude_from).map{|v| compile_regex_or_string(v)}
        table_recipes.keys.each do |table|
          if regexs.any?{|r| r === table}
            table_recipes[table] =  Data::Recipe::Skip.new(table, reason: "removed by -F")
          end
        end
      end
      if tables_fixed?
        new_recipes = Hash(String, Data::Recipe).new
        tables_fixed.each do |table|
          if recipe = table_recipes[table]?
            new_recipes[table] = recipe
          else
            new_recipes[table] = Data::Recipe::Ignore.new(table, reason: "PG schema not found")
          end
        end
        table_recipes.clear
        table_recipes.merge!(new_recipes)
      end
      return table_recipes.values
    else
      usage = Pretty.lines(usages_for_task, indent: "  ", delimiter: " ")
      abort "'-a', '-t', '-f', '-F' are exclusive. Please specify *ONE* of them.\n#{usage}"
    end    
  end

  private def compile_regex_or_string(v)
    if v.starts_with?("^") || v.ends_with?("$")
      Regex.new(v)
    else
      v
    end
  end
end
