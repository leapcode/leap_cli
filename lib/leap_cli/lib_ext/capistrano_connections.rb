module Capistrano
  class Configuration
    module Connections
      def failed!(server)
        @failure_callback.call(server) if @failure_callback
        Thread.current[:failed_sessions] << server
      end

      def call_on_failure(&block)
        @failure_callback = block
      end
    end
  end
end


