require 'paint'
require 'tee'

##
## LOGGING
##
## Ugh. This class does not work well with multiple threads!
##

module LeapCli
  extend self

  # logging options
  def log_level
    @log_level ||= 1
  end
  def log_level=(value)
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
    if value
      @log_output_stream = Tee.open(@log_file, :mode => 'a')
    end
  end

  def log_output_stream
    @log_output_stream || STDOUT
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
      options[:indent] ||= LeapCli.indent_level
      if message && LeapCli.log_level >= level
        line = ""
        line += "  " * (options[:indent])
        if options[:indent] > 0
          line += ' - '
        else
          line += ' = '
        end
        if title
          prefix = case title
            when :error     then ['error', :red, :bold]
            when :warning   then ['warning', :yellow, :bold]
            when :info      then ['info', :cyan, :bold]
            when :updated   then ['updated', :cyan, :bold]
            when :updating  then ['updating', :cyan, :bold]
            when :created   then ['created', :green, :bold]
            when :removed   then ['removed', :red, :bold]
            when :nochange  then ['no change', :magenta]
            when :loading   then ['loading', :magenta]
            when :missing   then ['missing', :yellow, :bold]
            when :run       then ['run', :magenta]
            when :failed    then ['FAILED', :red, :bold]
            when :completed then ['completed', :green, :bold]
            when :ran       then ['ran', :green, :bold]
            when :bail      then ['bailing out', :red, :bold]
            when :invalid   then ['invalid', :red, :bold]
            else [title.to_s, :cyan, :bold]
          end
          if options[:host]
            line += "[%s] %s " % [Paint[options[:host], prefix[1], prefix[2]], prefix[0]]
          else
            line += "%s " % Paint[prefix[0], prefix[1], prefix[2]]
          end
          if FILE_TITLES.include?(title) && message =~ /^\//
            message = LeapCli::Path.relative_path(message)
          end
        elsif options[:host]
          line += "[%s] " % options[:host]
        end
        line += "#{message}\n"
        LeapCli.log_output_stream.print(line)
        if block_given?
          LeapCli.indent_level += 1
          yield
          LeapCli.indent_level -= 1
        end
      end
    end
  end
end