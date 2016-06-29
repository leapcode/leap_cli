##
## LOGGING
##

module LeapCli
  module LogCommand
    @@logger = nil

    def log(*args, &block)
      logger.log(*args, &block)
    end

    def log_raw(*args, &block)
      logger.log_raw(*args, &block)
    end

    # global shared logger
    def logger
      @@logger ||= LeapCli::LeapLogger.new
    end

    # thread safe logger
    def new_logger
      logger.dup
    end

    # deprecated
    def log_level
      logger.log_level
    end
  end
end


module LeapCli
  class LeapLogger
    #
    # these are log titles typically associated with files
    #
    FILE_TITLES = [:updated, :created, :removed, :missing, :nochange, :loading]

    # TODO: use these
    IMPORTANT = 0
    INFO      = 1
    DEBUG     = 2
    TRACE     = 3

    attr_reader :log_output_stream, :log_file
    attr_accessor :indent_level, :log_level, :log_in_color

    def initialize()
      @log_level = 1
      @indent_level = 0
      @log_file = nil
      @log_output_stream = nil
      @log_in_color = true
    end

    def log_file=(value)
      @log_file = value
      if @log_file
        if !File.directory?(File.dirname(@log_file))
          Util.bail!('Invalid log file "%s", directory "%s" does not exist' % [@log_file, File.dirname(@log_file)])
        end
        @log_output_stream = File.open(@log_file, 'a')
      end
    end

    #
    # master logging function.
    #
    # arguments can be a String, Integer, Symbol, or Hash, in any order.
    #
    # * String: treated as the message to log.
    # * Integer: the log level (0, 1, 2)
    # * Symbol: the prefix title to colorize. may be one of
    #   [:error, :warning, :info, :updated, :created, :removed, :no_change, :missing]
    # * Hash: a hash of options.
    #     :wrap -- if true, appy intend to each line in message.
    #     :color -- apply color to message or prefix
    #     :style -- apply style to message or prefix
    #
    def log(*args)
      level   = args.grep(Integer).first || 1
      title   = args.grep(Symbol).first
      message = args.grep(String).first
      options = args.grep(Hash).first || {}
      host    = options[:host]
      unless message && @log_level >= level
        return
      end

      #
      # transform absolute path names
      #
      if title && FILE_TITLES.include?(title) && message =~ /^\//
        message = LeapCli::Path.relative_path(message)
      end

      #
      # apply filters
      #
      if title
        title, filter_flags = LogFilter.apply_title_filters(title.to_s)
      else
        message, filter_flags = LogFilter.apply_message_filters(message)
        return if message.nil?
      end
      options = options.merge(filter_flags)

      #
      # set line prefix
      #
      prefix = ""
      prefix += "[" + options[:host] + "] " if options[:host]
      prefix += title + " " if title

      #
      # write to the log file, always
      #
      log_raw(:log, nil, prefix) { message }

      #
      # log to stdout, maybe in color
      #
      if @log_in_color
        if options[:wrap]
          message = message.split("\n")
        end
        if options[:color]
          if host
            host = "[" + colorize(host, options[:color], options[:style]) + "] "
          elsif title
            title = colorize(title, options[:color], options[:style]) + " "
          else
            message = colorize(message, options[:color], options[:style])
          end
        elsif title
          title = colorize(title, :cyan, :bold) + " "
        end
        # new colorized prefix:
        prefix = [host, title].compact.join(' ')
      end
      log_raw(:stdout, options[:indent], prefix) { message }

      #
      # run block indented, if given
      #
      if block_given?
        @indent_level += 1
        yield
        @indent_level -= 1
      end
    end

    def debug(*args)
      self.log(3, *args)
    end

    #
    # Add a raw log entry, without any modifications (other than indent).
    # Content to be logged is yielded by the block.
    # Block may be either a string or array of strings.
    #
    # if mode == :stdout, output is sent to STDOUT.
    # if mode == :log, output is sent to log file, if present.
    #
    def log_raw(mode, indent=nil, prefix=nil, &block)
      # NOTE: using 'print' produces better results than 'puts'
      # when multiple threads are logging)
      if mode == :log
        if @log_output_stream
          messages = [yield].compact.flatten
          if messages.any?
            timestamp = Time.now.strftime("%b %d %H:%M:%S")
            messages.each do |message|
              message = message.rstrip
              next if message.empty?
              @log_output_stream.print("#{timestamp} #{prefix} #{message}\n")
            end
            @log_output_stream.flush
          end
        end
      elsif mode == :stdout
        messages = [yield].compact.flatten
        if messages.any?
          indent ||= @indent_level
          indent_str = ""
          indent_str += "  " * indent.to_i
          if indent.to_i > 0
            indent_str += ' - '
          else
            indent_str += ' = '
          end
          indent_str += prefix if prefix
          messages.each do |message|
            message = message.rstrip
            next if message.empty?
            STDOUT.print("#{indent_str}#{message}\n")
          end
        end
      end
    end

    def colorize(str, color, style=nil)
      codes = [FG_COLORS[color] || FG_COLORS[:default]]
      if style
        codes << EFFECTS[style] || EFFECTS[:nothing]
      end
      ["\033[%sm" % codes.join(';'), str, NO_COLOR].join
    end

    private

    EFFECTS = {
      :reset         => 0,  :nothing         => 0,
      :bright        => 1,  :bold            => 1,
      :underline     => 4,
      :inverse       => 7,  :swap            => 7,
    }
    NO_COLOR = "\033[0m"
    FG_COLORS = {
      :black   => 30,
      :red     => 31,
      :green   => 32,
      :yellow  => 33,
      :blue    => 34,
      :magenta => 35,
      :cyan    => 36,
      :white   => 37,
      :default => 39,
    }
    BG_COLORS = {
      :black   => 40,
      :red     => 41,
      :green   => 42,
      :yellow  => 43,
      :blue    => 44,
      :magenta => 45,
      :cyan    => 46,
      :white   => 47,
      :default => 49,
    }

  end
end

#
# A module to hide, modify, and colorize log entries.
#

module LeapCli
  module LogFilter
    #
    # options for formatters:
    #
    # :match       => regexp for matching a log line
    # :color       => what color the line should be
    # :style       => what style the line should be
    # :priority    => what order the formatters are applied in. higher numbers first.
    # :match_level => only apply filter at the specified log level
    # :level       => make this line visible at this log level or higher
    # :replace     => replace the matched text
    # :prepend     => insert text at start of message
    # :append      => append text to end of message
    # :exit        => force the exit code to be this (does not interrupt program, just
    #                 ensures a specific exit code when the program eventually exits)
    #
    FORMATTERS = [
      # TRACE
      { :match => /command finished/,          :color => :white,   :style => :dim, :match_level => 3, :priority => -10 },
      { :match => /executing locally/,         :color => :yellow,  :match_level => 3, :priority => -20 },

      # DEBUG
      #{ :match => /executing .*/,             :color => :green,   :match_level => 2, :priority => -10, :timestamp => true },
      #{ :match => /.*/,                       :color => :yellow,  :match_level => 2, :priority => -30 },
      { :match => /^transaction:/,             :level => 3 },

      # INFO
      { :match => /.*out\] (fatal:|ERROR:).*/, :color => :red,     :match_level => 1, :priority => -10 },
      { :match => /Permission denied/,         :color => :red,     :match_level => 1, :priority => -20 },
      { :match => /sh: .+: command not found/, :color => :magenta, :match_level => 1, :priority => -30 },

      # IMPORTANT
      { :match => /^(E|e)rr ::/,               :color => :red,     :match_level => 0, :priority => -10, :exit => 1},
      { :match => /^ERROR:/,                   :color => :red,                        :priority => -10, :exit => 1},
      #{ :match => /.*/,                        :color => :blue,    :match_level => 0, :priority => -20 },

      # CLEANUP
      #{ :match => /\s+$/,                      :replace => '', :priority => 0},

      # DEBIAN PACKAGES
      { :match => /^(Hit|Ign) /,                :color => :green,   :priority => -20},
      { :match => /^Err /,                      :color => :red,     :priority => -20},
      { :match => /^W(ARNING)?: /,              :color => :yellow,  :priority => -20},
      { :match => /^E: /,                       :color => :red,     :priority => -20},
      { :match => /already the newest version/, :color => :green,   :priority => -20},
      { :match => /WARNING: The following packages cannot be authenticated!/, :color => :red, :level => 0, :priority => -10},

      # PUPPET
      { :match => /^(W|w)arning: Not collecting exported resources without storeconfigs/, :level => 2, :color => :yellow, :priority => -10},
      { :match => /^(W|w)arning: Found multiple default providers for vcsrepo:/,          :level => 2, :color => :yellow, :priority => -10},
      { :match => /^(W|w)arning: .*is deprecated.*$/, :level => 2, :color => :yellow, :priority => -10},
      { :match => /^(W|w)arning: Scope.*$/,           :level => 2, :color => :yellow, :priority => -10},
      #{ :match => /^(N|n)otice:/,                     :level => 1, :color => :cyan,   :priority => -20},
      #{ :match => /^(N|n)otice:.*executed successfully$/, :level => 2, :color => :cyan, :priority => -15},
      { :match => /^(W|w)arning:/,                    :level => 0, :color => :yellow, :priority => -20},
      { :match => /^Duplicate declaration:/,          :level => 0, :color => :red,    :priority => -20},
      #{ :match => /Finished catalog run/,             :level => 0, :color => :green,  :priority => -10},
      { :match => /^APPLY COMPLETE \(changes made\)/, :level => 0, :color => :green, :style => :bold, :priority => -10},
      { :match => /^APPLY COMPLETE \(no changes\)/,   :level => 0, :color => :green, :style => :bold, :priority => -10},

      # PUPPET FATAL ERRORS
      { :match => /^(E|e)rr(or|):/,                :level => 0, :color => :red, :priority => -1, :exit => 1},
      { :match => /^Wrapped exception:/,           :level => 0, :color => :red, :priority => -1, :exit => 1},
      { :match => /^Failed to parse template/,     :level => 0, :color => :red, :priority => -1, :exit => 1},
      { :match => /^Execution of.*returned/,       :level => 0, :color => :red, :priority => -1, :exit => 1},
      { :match => /^Parameter matches failed:/,    :level => 0, :color => :red, :priority => -1, :exit => 1},
      { :match => /^Syntax error/,                 :level => 0, :color => :red, :priority => -1, :exit => 1},
      { :match => /^Cannot reassign variable/,     :level => 0, :color => :red, :priority => -1, :exit => 1},
      { :match => /^Could not find template/,      :level => 0, :color => :red, :priority => -1, :exit => 1},
      { :match => /^APPLY COMPLETE.*fail/,         :level => 0, :color => :red, :style => :bold, :priority => -1, :exit => 1},

      # TESTS
      { :match => /^PASS: /,                :color => :green,   :priority => -20},
      { :match => /^(FAIL|ERROR): /,        :color => :red,     :priority => -20},
      { :match => /^(SKIP|WARN): /,         :color => :yellow,  :priority => -20},
      { :match => /\d+ tests: \d+ passes, \d+ skips, 0 warnings, 0 failures, 0 errors/,
        :color => :green, :style => :bold, :priority => -20 },
      { :match => /\d+ tests: \d+ passes, \d+ skips, [1-9][0-9]* warnings, 0 failures, 0 errors/,
        :color => :yellow, :style => :bold,  :priority => -20 },
      { :match => /\d+ tests: \d+ passes, \d+ skips, \d+ warnings, \d+ failures, [1-9][0-9]* errors/,
        :color => :red, :style => :bold, :priority => -20 },
      { :match => /\d+ tests: \d+ passes, \d+ skips, \d+ warnings, [1-9][0-9]* failures, \d+ errors/,
        :color => :red, :style => :bold, :priority => -20 },

      # LOG SUPPRESSION
      { :match => /^(W|w)arning: You cannot collect without storeconfigs being set/, :level => 2, :priority => 10},
      { :match => /^(W|w)arning: You cannot collect exported resources without storeconfigs being set/, :level => 2, :priority => 10}
    ]

    SORTED_FORMATTERS = FORMATTERS.sort_by { |i| -(i[:priority] || i[:prio] || 0) }

    #
    # same as normal formatters, but only applies to the title, not the message.
    #
    TITLE_FORMATTERS = [
      # red
      { :match => /error/, :color => :red, :style => :bold },
      { :match => /fatal_error/, :replace => 'fatal error:', :color => :red, :style => :bold },
      { :match => /removed/, :color => :red, :style => :bold },
      { :match => /failed/, :replace => 'FAILED', :color => :red, :style => :bold },
      { :match => /bail/, :replace => 'bailing out', :color => :red, :style => :bold },
      { :match => /invalid/, :color => :red, :style => :bold },

      # yellow
      { :match => /warning/, :replace => 'warning:', :color => :yellow, :style => :bold },
      { :match => /missing/, :color => :yellow, :style => :bold },
      { :match => /skipping/, :color => :yellow, :style => :bold },

      # green
      { :match => /created/, :color => :green, :style => :bold },
      { :match => /completed/, :color => :green, :style => :bold },
      { :match => /ran/, :color => :green, :style => :bold },

      # cyan
      { :match => /note/, :replace => 'NOTE:', :color => :cyan, :style => :bold },

      # magenta
      { :match => /nochange/, :replace => 'no change', :color => :magenta },
      { :match => /loading/, :color => :magenta },
    ]

    def self.apply_message_filters(message)
      return self.apply_filters(SORTED_FORMATTERS, message)
    end

    def self.apply_title_filters(title)
      return self.apply_filters(TITLE_FORMATTERS, title)
    end

    private

    def self.apply_filters(formatters, message)
      level = LeapCli.logger.log_level
      result = {}
      formatters.each do |formatter|
        if (formatter[:match_level] == level || formatter[:match_level].nil?)
          if message =~ formatter[:match]
            # puts "applying formatter #{formatter.inspect}"
            result[:level] = formatter[:level] if formatter[:level]
            result[:color] = formatter[:color] if formatter[:color]
            result[:style] = formatter[:style] || formatter[:attribute] # (support original cap colors)

            message.gsub!(formatter[:match], formatter[:replace]) if formatter[:replace]
            message.replace(formatter[:prepend] + message) unless formatter[:prepend].nil?
            message.replace(message + formatter[:append])  unless formatter[:append].nil?
            message.replace(Time.now.strftime('%Y-%m-%d %T') + ' ' + message) if formatter[:timestamp]

            if formatter[:exit]
              LeapCli::Util.exit_status(formatter[:exit])
            end

            # stop formatting, unless formatter was just for string replacement
            break unless formatter[:replace]
          end
        end
      end

      if result[:color] == :hide
        return [nil, {}]
      else
        return [message, result]
      end
    end

  end
end
