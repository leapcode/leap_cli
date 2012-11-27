#
# A drop in replacement for Capistrano::Logger that integrates better with LEAP CLI.
#

require 'capistrano/logger'

#
# from Capistrano::Logger
# =========================
#
# IMPORTANT = 0
# INFO      = 1
# DEBUG     = 2
# TRACE     = 3
# MAX_LEVEL = 3
# COLORS = {
#   :none     => "0",
#   :black    => "30",
#   :red      => "31",
#   :green    => "32",
#   :yellow   => "33",
#   :blue     => "34",
#   :magenta  => "35",
#   :cyan     => "36",
#   :white    => "37"
# }
# STYLES = {
#   :bright     => 1,
#   :dim        => 2,
#   :underscore => 4,
#   :blink      => 5,
#   :reverse    => 7,
#   :hidden     => 8
# }
#

module LeapCli
  class Logger < Capistrano::Logger

    def initialize(options={})
      @options = options
      @level = options[:level] || 0
    end

    def log(level, message, line_prefix=nil, options={})
      # formatting modifies message & line_prefix, so create dups
      message = message.dup
      options = options.dup
      if !line_prefix.nil?
        if !line_prefix.is_a?(String)
          line_prefix = line_prefix.to_s.dup
        else
          line_prefix = line_prefix.dup
        end
      end
      options[:level] ||= level

      # apply formatting
      apply_formatting(message, line_prefix, options)

      # print message
      if options[:level] <= self.level
        message.lines.each do |line|
          line = line.strip
          line_prefix = line_prefix.strip if line_prefix
          if line.chars.any?
            if line_prefix
              LeapCli::log "[#{line_prefix}] #{line}"
            else
              LeapCli::log line
            end
          end
        end
      end
    end

    private

    ##
    ## FORMATTING
    ##

    @formatters = [
      # TRACE
      { :match => /command finished/,          :color => :white,   :style => :dim, :match_level => 3, :priority => -10 },
      { :match => /executing locally/,         :color => :yellow,  :match_level => 3, :priority => -20 },

      # DEBUG
      #{ :match => /executing .*/,             :color => :green,   :match_level => 2, :priority => -10, :timestamp => true },
      #{ :match => /.*/,                        :color => :yellow,  :match_level => 2, :priority => -30 },
      { :match => /^transaction:/,             :level => 3 },

      # INFO
      { :match => /.*out\] (fatal:|ERROR:).*/, :color => :red,     :match_level => 1, :priority => -10 },
      { :match => /Permission denied/,         :color => :red,     :match_level => 1, :priority => -20 },
      { :match => /sh: .+: command not found/, :color => :magenta, :match_level => 1, :priority => -30 },

      # IMPORTANT
      { :match => /^err ::/,                   :color => :red,     :match_level => 0, :priority => -10 },
      { :match => /.*/,                        :color => :blue,    :match_level => 0, :priority => -20 },

      # PREFIX CLEANUP
      { :match => /(err|out) :: /,             :replace => '', :priority => 0},

      # DEBIAN PACKAGES
      { :match => /^(Hit|Ign) /,                :color => :green,   :priority => -20},
      { :match => /^Err /,                      :color => :red,     :priority => -20},
      { :match => /^W: /,                       :color => :yellow,  :priority => -20},
      { :match => /already the newest version/, :color => :green,   :priority => -20},

      # PUPPPET
      { :match => /^warning: .*is deprecated.*$/,  :level => 2, :color => :yellow, :priority => -10},
      { :match => /^notice:/,                      :level => 1, :color => :cyan,   :priority => -20},
      { :match => /^err:/,                         :level => 0, :color => :red,    :priority => -20},
      { :match => /^warning:/,                     :level => 0, :color => :yellow, :priority => -20},
      { :match => /Finished catalog run/,          :level => 0, :color => :green,  :priority => -10},
    ]

    def apply_formatting(message, line_prefix = nil, options={})
      color = options[:color] || :none
      style = options[:style]
      continue = true
      self.class.sorted_formatters.each do |formatter|
        break unless continue
        if (formatter[:match_level] == level || formatter[:match_level].nil?)
          [message, line_prefix].compact.each do |str|
            if str =~ formatter[:match]
              options[:level] = formatter[:level] if formatter[:level]
              color = formatter[:color] if formatter[:color]
              style = formatter[:style] || formatter[:attribute] # (support original cap colors)

              str.gsub!(formatter[:match], formatter[:replace]) if formatter[:replace]
              str.replace(formatter[:prepend] + str) unless formatter[:prepend].nil?
              str.replace(str + formatter[:append])  unless formatter[:append].nil?
              str.replace(Time.now.strftime('%Y-%m-%d %T') + ' ' + str) if formatter[:timestamp]

              # stop formatting, unless formatter was just for string replacement
              continue = false unless formatter[:replace]
            end
          end
        end
      end

      return if color == :hide
      return if color == :none && style.nil?

      term_color = COLORS[color]
      term_style = STYLES[style]
      if line_prefix.nil?
        message.replace format(message, term_color, term_style)
      else
        line_prefix.replace format(line_prefix, term_color, term_style)
      end
    end

  end
end
