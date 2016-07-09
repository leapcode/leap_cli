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
    FILE_TITLES = %w(updated created removed missing nochange loading)

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
      if title
        title = title.to_s
      end
      if @log_level < level || (title.nil? && message.nil?)
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
      # LogFilter will not be defined if no platform was loaded.
      #
      if defined?(LeapCli::LogFilter)
        if title
          title, filter_flags = LogFilter.apply_title_filters(title)
        else
          message, filter_flags = LogFilter.apply_message_filters(message)
          return if message.nil?
        end
        options = options.merge(filter_flags)
      end

      #
      # set line prefix
      #
      prefix = prefix_str(host, title)

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
            host = colorize(host, options[:color], options[:style])
          elsif title
            title = colorize(title, options[:color], options[:style])
          else
            message = colorize(message, options[:color], options[:style])
          end
        elsif title
          title = colorize(title, :cyan, :bold)
        end
        # new colorized prefix:
        prefix = prefix_str(host, title)
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
      if str.is_a?(String)
        ["\033[%sm" % codes.join(';'), str, NO_COLOR].join
      elsif str.is_a?(Array)
        str.map { |s|
          ["\033[%sm" % codes.join(';'), s, NO_COLOR].join
        }
      end
    end

    private

    def prefix_str(host, title)
      prefix = ""
      prefix += "[" + host + "] " if host
      prefix += title + " " if title
      prefix += " " if !prefix.empty? && prefix !~ / $/
      return prefix
    end

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

