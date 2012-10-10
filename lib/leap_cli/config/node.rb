module LeapCli
  module Config
    class Node < Base

      def nodes
        @manager.nodes
      end

      def services
        self['services'] || []
      end

      def tags
        self['tags'] || []
      end

    end
  end
end
