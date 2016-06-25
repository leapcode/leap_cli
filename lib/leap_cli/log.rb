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
      LeapCli::LeapLogger.new
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
    # * Hash: a hash of options. so far, only :indent is supported.
    #
    def log(*args)
      level   = args.grep(Integer).first || 1
      title   = args.grep(Symbol).first
      message = args.grep(String).first
      options = args.grep(Hash).first || {}
      unless message && @log_level >= level
        return
      end
      clear_prefix, colored_prefix = calculate_prefix(title, options)

      #
      # transform absolute path names
      #
      if title && FILE_TITLES.include?(title) && message =~ /^\//
        message = LeapCli::Path.relative_path(message)
      end

      #
      # log to the log file, always
      #
      log_raw(:log, nil, clear_prefix) { message }

      #
      # log to stdout, maybe in color
      #
      if @log_in_color
        prefix = colored_prefix
        if options[:wrap]
          message = message.split("\n")
        end
      else
        prefix = clear_prefix
      end
      indent = options[:indent]
      log_raw(:stdout, indent, prefix) { message }

      #
      # run block indented, if given
      #
      if block_given?
        @indent_level += 1
        yield
        @indent_level -= 1
      end
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
              message = message.strip
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
            message = message.strip
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

    def calculate_prefix(title, options)
      clear_prefix = colored_prefix = ""
      if title
        prefix_options = case title
          when :error     then ['error', :red, :bold]
          when :fatal_error then ['fatal error:', :red, :bold]
          when :warning   then ['warning:', :yellow, :bold]
          when :info      then ['info', :cyan, :bold]
          when :note      then ['NOTE:', :cyan, :bold]
          when :updated   then ['updated', :cyan, :bold]
          when :updating  then ['updating', :cyan, :bold]
          when :created   then ['created', :green, :bold]
          when :removed   then ['removed', :red, :bold]
          when :nochange  then ['no change', :magenta]
          when :loading   then ['loading', :magenta]
          when :missing   then ['missing', :yellow, :bold]
          when :skipping  then ['skipping', :yellow, :bold]
          when :run       then ['run', :cyan, :bold]
          when :running   then ['running', :cyan, :bold]
          when :failed    then ['FAILED', :red, :bold]
          when :completed then ['completed', :green, :bold]
          when :ran       then ['ran', :green, :bold]
          when :bail      then ['bailing out', :red, :bold]
          when :invalid   then ['invalid', :red, :bold]
          else [title.to_s, :cyan, :bold]
        end
        if options[:host]
          clear_prefix = "[%s] %s " % [options[:host], prefix_options[0]]
          colored_prefix = "[%s] %s " % [colorize(options[:host], prefix_options[1], prefix_options[2]), prefix_options[0]]
        else
          clear_prefix = "%s " % prefix_options[0]
          colored_prefix = "%s " % colorize(prefix_options[0], prefix_options[1], prefix_options[2])
        end
      elsif options[:host]
        clear_prefix = "[%s] " % options[:host]
        if options[:color]
          colored_prefix = "[%s] " % colorize(options[:host], options[:color])
        else
          colored_prefix = clear_prefix
        end
      end
      return [clear_prefix, colored_prefix]
    end

  end
end