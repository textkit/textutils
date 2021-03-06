# encoding: utf-8

# fix: move into TextUtils namespace/module!!

class TreeReader

  include LogUtils::Logging

  def self.from_file( path )
    ## nb: assume/enfore utf-8 encoding (with or without BOM - byte order mark)
    ## - see textutils/utils.rb
   text = File.read_utf8( path )
   self.from_string( text )
  end

  def self.from_string( text )
    self.new( text )
  end

  def initialize( text )
    @text = text
  end

  TreeItem = Struct.new( :level, :key, :value )

  KEY_REGEX     = /
                      ([0-9][0-9A-Za-z]*)   ## key starting with a nummer
                        |
                      ([a-z]+)   ## key all lowercase e.g. bt,n,etc.
                        |
                      ([A-Z]+)   ## key all uppercase e.g. BT,N,etc
                  /x

  LEVEL_REGEX   = /[.*\-]+/     ## e.g. .. or .... etc. allow --/** too (e.g. lets you use markdown or ascii doc lists etc.)


  def each_line  
    stack    = []     # note: last_level  => stack.size; starts w/ 0
    times    = 2      # assume two indents factor (e.g. .. =2, ....=3 etc. ) for now

    reader = LineReader.from_string( @text )
    reader.each_line do |line|

      logger.debug "[TreeReader]  line (before) => >#{line}<"

      s = StringScanner.new( line )
      s.skip( /[ \t]+/ )   # remove whitespace

      key = s.scan( KEY_REGEX )
      if key
        s.skip( /[ \t]+/ )   # remove whitespace
      end

      level_str = s.scan( LEVEL_REGEX )
      if level_str
        ## FIX!! todo/check: make sure level_str.size is a multiple of two !! (e.g. 2,4,6,etc.)
        level = (level_str.size/times)+1
        s.skip( /[ \t]+/ )   # remove whitespace
      else
        level = 1   ## no level found; assume top level (start w/ 1)
      end

      ## assume rest is record
      rest = s.rest.rstrip  ## note: remove trailing whitespaces

      level_diff = level - stack.size

      if level_diff > 0
        logger.debug "[TreeReader]    up  +#{level_diff}"
        ## FIX!!! todo/check/verify/assert: always must be +1
      elsif level_diff < 0
        logger.debug "[TreeReader]    down #{level_diff}"
        level_diff.abs.times { stack.pop }
        stack.pop
      else
        ## same level
        stack.pop
      end

      item = TreeItem.new
      item.level = level
      item.key   = key
      item.value = rest

      stack.push( item )

      ## for debugging - show tree item (note) hierarchy 
      names = stack.map { |it| "(#{it.level}) #{it.value}" }
      logger.debug "[TreeReader]    #{names.join( ' › ' )}  -- key: >#{key}<, level: >#{level}<, rest: >#{rest}<"

      yield( stack )
    end

  end # method each_line


  def check   ## rename to lint/analyze/etc. - why? why not??

    ## track stats for debugging (linting/checking)
    stats = {
      levels: Hash.new( 0 ),   ## note: set default to 0
      ## check for duplicate entries (values/names)
      values: {}
    }

    each_line do |stack|
      node = stack.last

      ## track stats for number of nodes
      levels = stats[:levels]
      levels[node.level] += 1

      ## collect all values (for a level) in an array
      values = stats[:values][node.level] || []
      values << node.value
      stats[:values][node.level] = values
    end

    puts "stats:"
    pp stats[:levels]  

#    puts "values:"
#    pp stats[:values]

    ## check for duplicates (using group_by)
    values = stats[:values]
    values.each do |l,ary|
      puts "checking level #{l} - #{ary.size} node(s)..."
      duplicates = ary.group_by { |e| e }.select { |k, v| v.size > 1 }
      if duplicates.size > 0
        puts "  #{duplicates.size} duplicate(s) in level #{l}:"
        pp duplicates
      end
    end

  end # method check

end # class TreeReader

