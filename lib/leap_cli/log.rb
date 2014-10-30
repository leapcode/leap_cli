require 'paint'

##
## LOGGING
##
## Ugh. This class does not work well with multiple threads!
##

module LeapCli
  extend self

  attr_accessor :log_in_color

  # logging options
  def log_level
    @log_level ||= 1
  end
  def set_log_level(value)
    @log_level = value
  end

  def indent_level
    @indent_level ||= 0
  end
  def indent_level=(value)
    @indent_level = value
  end

  def log_file
    @log_file
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

  def log_output_stream
    @log_output_stream
  end

end


module LeapCli
  module Log
    #
    # these are log titles typically associated with files
    #
    FILE_TITLES = [:updated, :created, :removed, :missing, :nochange, :loading]


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
      unless message && LeapCli.log_level >= level
        return
      end

      # prefix
      clear_prefix = colored_prefix = ""
      if title
        prefix_options = case title
          when :error     then ['error', :red, :bold]
          when :fatal_error then ['fatal error', :red, :bold]
          when :warning   then ['warning:', :yellow, :bold]
          when :info      then ['info', :cyan, :bold]
          when :updated   then ['updated', :cyan, :bold]
          when :updating  then ['updating', :cyan, :bold]
          when :created   then ['created', :green, :bold]
          when :removed   then ['removed', :red, :bold]
          when :nochange  then ['no change', :magenta]
          when :loading   then ['loading', :magenta]
          when :missing   then ['missing', :yellow, :bold]
          when :skipping  then ['skipping', :yellow, :bold]
          when :run       then ['run', :magenta]
          when :failed    then ['FAILED', :red, :bold]
          when :completed then ['completed', :green, :bold]
          when :ran       then ['ran', :green, :bold]
          when :bail      then ['bailing out', :red, :bold]
          when :invalid   then ['invalid', :red, :bold]
          else [title.to_s, :cyan, :bold]
        end
        if options[:host]
          clear_prefix = "[%s] %s " % [options[:host], prefix_options[0]]
          colored_prefix = "[%s] %s " % [Paint[options[:host], prefix_options[1], prefix_options[2]], prefix_options[0]]
        else
          clear_prefix = "%s " % prefix_options[0]
          colored_prefix = "%s " % Paint[prefix_options[0], prefix_options[1], prefix_options[2]]
        end
      elsif options[:host]
        clear_prefix = colored_prefix =  "[%s] " % options[:host]
      end

      # transform absolute path names
      if title && FILE_TITLES.include?(title) && message =~ /^\//
        message = LeapCli::Path.relative_path(message)
      end

      log_raw(:log, nil)                   { [clear_prefix, message].join }
      if LeapCli.log_in_color
        log_raw(:stdout, options[:indent]) { [colored_prefix, message].join }
      else
        log_raw(:stdout, options[:indent]) { [clear_prefix, message].join }
      end

      # run block, if given
      if block_given?
        LeapCli.indent_level += 1
        yield
        LeapCli.indent_level -= 1
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
    def log_raw(mode, indent=nil, &block)
      # NOTE: print message (using 'print' produces better results than 'puts' when multiple threads are logging)
      if mode == :log
        if LeapCli.log_output_stream
          messages = [yield].compact.flatten
          if messages.any?
            timestamp = Time.now.strftime("%b %d %H:%M:%S")
            messages.each do |message|
              LeapCli.log_output_stream.print("#{timestamp} #{message}\n")
            end
            LeapCli.log_output_stream.flush
          end
        end
      elsif mode == :stdout
        messages = [yield].compact.flatten
        if messages.any?
          indent ||= LeapCli.indent_level
          indent_str = ""
          indent_str += "  " * indent.to_i
          if indent.to_i > 0
            indent_str += ' - '
          else
            indent_str += ' = '
          end
          messages.each do |message|
            STDOUT.print("#{indent_str}#{message}\n")
          end
        end
      end
    end

  end
end