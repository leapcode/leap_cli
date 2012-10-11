module LeapCli
  module Config
    #
    # A list of Config::Object instances (internally stored as a hash)
    #
    class ObjectList < Hash

      def initialize(config=nil)
        if config
          self.add(config['name'], config)
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
          results = Config::ObjectList.new
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


      # def <<(object)
      #   if object.is_a? Config::ObjectList
      #     self.merge!(object)
      #   elsif object['name']
      #     self[object['name']] = object
      #   else
      #     raise ArgumentError.new('argument must be a Config::Object or a Config::ObjectList')
      #   end
      # end

      def add(name, object)
        self[name] = object
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
          result << self[name].get(field)
        end
        result
      end

    end
  end
end
