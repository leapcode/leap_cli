require 'versionomy'

module Leap

  class Platform
    class << self
      #
      # configuration
      #

      attr_reader :version
      attr_reader :compatible_cli
      attr_accessor :facts
      attr_accessor :paths
      attr_accessor :node_files
      attr_accessor :monitor_username
      attr_accessor :reserved_usernames

      attr_accessor :hiera_path
      attr_accessor :files_dir
      attr_accessor :leap_dir
      attr_accessor :init_path

      attr_accessor :default_puppet_tags

      def define(&block)
        # some defaults:
        @reserved_usernames = []
        @hiera_path = '/etc/leap/hiera.yaml'
        @leap_dir   = '/srv/leap'
        @files_dir  = '/srv/leap/files'
        @init_path  = '/srv/leap/initialized'
        @default_puppet_tags = []

        self.instance_eval(&block)

        @version ||= Versionomy.parse("0.0")
      end

      def version=(version)
        @version = Versionomy.parse(version)
      end

      def compatible_cli=(range)
        @compatible_cli = range
        @minimum_cli_version = Versionomy.parse(range.first)
        @maximum_cli_version = Versionomy.parse(range.last)
      end

      #
      # return true if the cli_version is compatible with this platform.
      #
      def compatible_with_cli?(cli_version)
        cli_version = Versionomy.parse(cli_version)
        cli_version >= @minimum_cli_version && cli_version <= @maximum_cli_version
      end

      #
      # return true if the platform version is within the specified range.
      #
      def version_in_range?(range)
        if range.is_a? String
          range = range.split('..')
        end
        minimum_platform_version = Versionomy.parse(range.first)
        maximum_platform_version = Versionomy.parse(range.last)
        @version >= minimum_platform_version && @version <= maximum_platform_version
      end

      def major_version
        if @version.major == 0
          "#{@version.major}.#{@version.minor}"
        else
          @version.major
        end
      end

      def method_missing(method, *args)
        puts
        puts "WARNING:"
        puts "  leap_cli is out of date and does not understand `#{method}`."
        puts "  called from: #{caller.first}"
        puts "  please upgrade to a newer leap_cli"
      end

    end

  end

end