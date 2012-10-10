module LeapCli
  module Config
    class List < Hash

      def initialize(config=nil)
        if config
          self << config
        end
      end

      #
      # if the key is a hash, we treat it as a condition and filter all the configs using the condition
      #
      # for example:
      #
      #   nodes[:public_dns => true]
      #
      # will return a ConfigList with node configs that have public_dns set to true
      #
      def [](key)
        if key.is_a? Hash
          results = List.new
          field, match_value = key.to_a.first
          field = field.is_a?(Symbol) ? field.to_s : field
          match_value = match_value.is_a?(Symbol) ? match_value.to_s : match_value
          each do |name, config|
            value = config[field]
            if !value.nil?
              if value.is_a? Array
                if value.includes?(match_value)
                  results[name] = config
                end
              else
                if value == match_value
                  results[name] = config
                end
              end
            end
          end
          results
        else
          super
        end
      end

      def <<(config)
        if config.is_a? Config::List
          self.deep_merge!(config)
        elsif config['name']
          self[config['name']] = config
        else
          raise ArgumentError.new('argument must be a Config::Base or a Config::List')
        end
      end

      #
      # converts the hash of configs into an array of hashes, with ONLY the specified fields
      #
      def fields(*fields)
        result = []
        keys.sort.each do |name|
          result << self[name].pick(*fields)
        end
        result
      end

      #
      # like fields(), but returns an array of values instead of an array of hashes.
      #
      def field(field)
        field = field.to_s
        result = []
        keys.sort.each do |name|
          result << self[name][field]
        end
        result
      end

    end
  end
end
