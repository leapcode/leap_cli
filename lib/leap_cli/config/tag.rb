module LeapCli
  module Config
    class Tag < Base

      def nodes
        @nodes ||= Config::List.new
      end

      def services
        @manager.services
      end

      def tags
        @manager.tags
      end

    end
  end
end
