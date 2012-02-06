require 'redis'
require 'benchmark'
require 'progressbar'
require 'terminal-table'
require 'algorithms'
module Redu
  class RedisKeyValue
    attr_accessor :key,:bytesize,:type
  end

  class KeyPrefix
    attr_accessor :count, :bytesize
  end

  class WorstOffenderSet

    def initialize(max_count)
      @offenders = {}
      @max_count = max_count
      @least_worst_object = nil

      @offenders = Containers::MinHeap.new
    end

    def add(redis_debug_object)
      # If it's full and you aren't big enough skip you
      #puts "Least Worst Object: #{@least_worst_object.inspect}"
      if @offenders.size < @max_count
        @offenders.push(redis_debug_object.bytesize,redis_debug_object)
      else
        min = @offenders.min
        if min.bytesize < redis_debug_object.bytesize
          @offenders.pop
          @offenders.push(redis_debug_object.bytesize,redis_debug_object)
        end
      end
    end

    def max_sort
      output = []
      loop do 
        output << @offenders.pop
        break if @offenders.size == 0
      end
      output.reverse
    end

    def sorted_by_offense
      sorted_offenders = @offenders.sort do |a,b|
        b[1].bytesize <=> a[1].bytesize
      end
      output_offenders = []
      sorted_offenders.each do |pair|
        output_offenders << pair[1]
      end
      return output_offenders
    end
  end

  class RedisDebugObject
    # "Value at:0x7f93e48464e0 refcount:1 encoding:raw serializedlength:230 lru:710236 lru_seconds_idle:2040"
    attr_accessor :bytesize,:key

    def self.initialize_from_string(key,string)
      RedisDebugObject.new(key,string)
    end

    def initialize(key,string)
      @key = key
      if string =~ /serializedlength:(\d+)/
        @bytesize = $1.to_i
      else
        raise "Invalid matching for #{string}"
      end
    end

    def inspect
      "rdo:(#{@key},#{@bytesize})"
    end

    def <=>(other)
      self.bytesize <=> other.bytesize
    end
  end

  class Analyzer
    def initialize(options)
      @redis = Redis.new(options)
      @delimiter = options[:delimiter]
      @prefixes = {}
      @worst_offender_set = WorstOffenderSet.new(options[:worst_offender_count])
    end

    def start
      keys = []
      STDERR.puts "Loading Keys for Analysis. This may take a few minutes"
      keys = @redis.keys
      pb = ProgressBar.new("Analyzing",keys.size)
      keys.each do |key|
        analyze_key(key)
        pb.inc
      end
      pb.finish

      output_prefix_table
      output_worst_offenders_table
    end

    protected
    GIGA_SIZE = 1073741824.0
    MEGA_SIZE = 1048576.0
    KILO_SIZE = 1024.0

    def human_size(bytesize)
      precision = 3
      # Return the file size with a readable style.
      if bytesize == 1 
        "1 Byte"
      elsif bytesize < KILO_SIZE 
        "%d Bytes" % bytesize
      elsif bytesize < MEGA_SIZE 
        "%.#{precision}f KB" % (bytesize / KILO_SIZE)
      elsif bytesize < GIGA_SIZE 
        "%.#{precision}f MB" % (bytesize / MEGA_SIZE)
      else 
        "%.#{precision}f GB" % (bytesize / GIGA_SIZE)
      end
    end

    def output_prefix_table
      rows = []
      sorted_prefixes = @prefixes.sort do |a,b|
        b[1].bytesize <=> a[1].bytesize
      end

      sorted_prefixes.each do |pair|
        prefix = pair[1]
        rows << [pair[0],prefix.count,human_size(prefix.bytesize)]
      end

      table = Terminal::Table.new :title => "Prefixes", :headings => ['Prefix', 'Count', 'Size'], :rows => rows
      table.align_column(1,:right)
      table.align_column(2,:right)
      puts table
    end

    def output_worst_offenders_table
      sorted_offenders = @worst_offender_set.max_sort
      rows = []
      sorted_offenders.each do |offender|
        rows << [offender.key,human_size(offender.bytesize)]
      end
      table = Terminal::Table.new :title => "Worst Offenders", :headings => ['Key', 'Size'], :rows => rows
      table.align_column(1,:right)
      puts table
    end

    def derive_type
    end

    def derive_prefix(key)
      first_delimiter = key.index(@delimiter)
      if !first_delimiter.nil?
        prefix = key[0,first_delimiter]
        return prefix
      end
      return nil
    end

    def analyze_key(key)
      begin
        obj_str = @redis.debug("OBJECT", key)

        rdo = RedisDebugObject.initialize_from_string(key,obj_str)

        prefix_str = derive_prefix(key)
        if prefix_str
          prefix = @prefixes[prefix_str]
          if !prefix
            prefix = KeyPrefix.new
            prefix.count = 1
            prefix.bytesize = rdo.bytesize
            @prefixes[prefix_str] = prefix
          else
            prefix.count += 1
            prefix.bytesize += rdo.bytesize
          end
        end

        @worst_offender_set.add(rdo)
      rescue # Many times a key will be gone by the time we get to it in the array
      end
    end
  end
end
