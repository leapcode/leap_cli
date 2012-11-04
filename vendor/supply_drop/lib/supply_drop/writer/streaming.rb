begin
  require 'paint'
rescue
end

module SupplyDrop
  module Writer
    class Streaming
      def initialize(logger)
        @mode = Capistrano::Logger::DEBUG
        @logger = logger
      end

      def collect_output(host, data)
        if data =~ /^(notice|err|warning):/
          @mode = $1

          # force the printing of 'finished catalog run' if there have not been any errors
          if @mode == 'notice' && !@error_encountered && data =~ /Finished catalog run/
            @mode = 'forced_notice'
          elsif @mode == 'err'
            @error_encountered = true
          end
        end

        # log each line, colorizing the hostname
        data.lines.each do |line|
          if line =~ /\w/
            @logger.log log_level, line.sub(/\n$/,''), colorize(host)
          end
        end
      end

      def log_level
        case @mode
          when 'err'     then Capistrano::Logger::IMPORTANT
          when 'warning' then Capistrano::Logger::INFO
          when 'notice'  then Capistrano::Logger::DEBUG
          else Capistrano::Logger::IMPORTANT
        end
      end

      def colorize(str)
        if defined? Paint
          color = case @mode
            when 'err'     then :red
            when 'warning' then :yellow
            when 'notice'  then :cyan
            when 'forced_notice' then :cyan
            else :clear
          end
          Paint[str, color, :bold]
        else
          str
        end
      end

      def all_output_collected
      end
    end
  end
end
