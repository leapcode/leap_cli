require 'paint'

##
## LOGGING
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
        print "  " * (options[:indent]+1)
        if options[:indent] > 0
          print '- '
        else
          print '= '
        end
        if title
          prefix = case title
            when :error     then Paint['error', :red, :bold]
            when :warning   then Paint['warning', :yellow, :bold]
            when :info      then Paint['info', :cyan, :bold]
            when :updated   then Paint['updated', :cyan, :bold]
            when :updating  then Paint['updating', :cyan, :bold]
            when :created   then Paint['created', :green, :bold]
            when :removed   then Paint['removed', :red, :bold]
            when :nochange  then Paint['no change', :magenta]
            when :loading   then Paint['loading', :magenta]
            when :missing   then Paint['missing', :yellow, :bold]
            when :run       then Paint['run', :magenta]
            when :failed    then Paint['FAILED', :red, :bold]
            when :completed then Paint['completed', :green, :bold]
            when :ran       then Paint['ran', :green, :bold]
            when :bail      then Paint['bailing out', :red, :bold]
            else Paint[title.to_s, :cyan, :bold]
          end
          print "#{prefix} "
          if FILE_TITLES.include?(title) && message =~ /^\//
            message = LeapCli::Path.relative_path(message)
          end
        end
        puts "#{message}"
        if block_given?
          LeapCli.indent_level += 1
          yield
          LeapCli.indent_level -= 1
        end
      end
    end
  end
end