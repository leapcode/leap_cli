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

      def define(&block)
        # some sanity defaults:
        @reserved_usernames = []
        self.instance_eval(&block)
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
    end

  end

end