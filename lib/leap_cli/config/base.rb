module LeapCli
  module Config
    #
    # This class represents the configuration for a single node, service, or tag.
    #
    class Base < Hash

      def initialize(manager=nil, node=nil)
        @manager = manager
        @node = node || self
      end

      ##
      ## FETCHING VALUES
      ##

      #
      # lazily eval dynamic values when we encounter them.
      #
      def [](key)
        value = fetch(key, nil)
        if value.is_a? Array
          value
        elsif value.nil?
          nil
        else
          if value =~ /^= (.*)$/
            begin
              value = eval($1)
              self[key] = value
            rescue Exception => exc
              puts "Eval error in '#{name}'"
              puts "   string: #{$1}"
              puts "   error: #{exc}"
            end
          end
          value
        end
      end

      def name
        @node['name']
      end

      #
      # make hash addressable like an object (e.g. obj['name'] available as obj.name)
      #
      def method_missing(method, *args, &block)
        method = method.to_s
        if self.has_key?(method)
          self[method]
        elsif @node != self
          @node.send(method) # send call up the tree...
        else
          raise NoMethodError.new(method)
        end
      end

      #
      # a deep (recursive) merge with another hash or node.
      #
      def deep_merge!(hsh)
        hsh.each do |key,new_value|
          old_value = self[key]
          if old_value.is_a?(Hash) || new_value.is_a?(Hash)
            # merge hashes
            value = Base.new(@manager, @node)
            old_value.is_a?(Hash) ? value.deep_merge!(old_value) : (value[key] = old_value if old_value.any?)
            new_value.is_a?(Hash) ? value.deep_merge!(new_value) : (value[key] = new_value if new_value.any?)
          elsif old_value.is_a?(Array) || new_value.is_a?(Array)
            # merge arrays
            value = []
            old_value.is_a?(Array) ? value += old_value : value << old_value
            new_value.is_a?(Array) ? value += new_value : value << new_value
            value.compact!
          elsif new_value.nil?
            value = old_value
          elsif old_value.nil?
            value = new_value
          elsif old_value.is_a?(Boolean) && new_value.is_a?(Boolean)
            value = new_value
          elsif old_value.class != new_value.class
            raise 'Type mismatch. Cannot merge %s with %s. Key value is %s, name is %s.' % [old_value.class, new_value.class, key, name]
          else
            value = new_value
          end
          self[key] = value
        end
        self
      end

      #def deep_merge!(new_node)
      #  new_node.each do |key, value|
      #    if value.is_a? self.class
      #      value = Base.new(@manager, @node).deep_merge!(value)
      #    self[key] = new_node[key]
      #  end
      #  self
      #end

      #
      # like a normal deep_merge, but replace any hash it encounters with a Config::Base
      #
      #def deep_merge(other_hash)
      #  p [self['name'], other_hash['name']]
      #  self.merge(other_hash) do |key, oldval, newval|
      #    oldval = oldval.to_hash if oldval.respond_to?(:to_hash)
      #    newval = newval.to_hash if newval.respond_to?(:to_hash)
      #    p key
      #    p oldval.class
      #    p newval.class
      #    if oldval.class.to_s == 'Hash' && newval.class.to_s == 'Hash'
      #      oldval.deep_merge(newval)
      #    elsif newval.class.to_s == 'Hash'
      #      p key
      #      Base.new(@manager, node).replace(newval)
      #    else
      #      newval
      #    end
      #  end
      #end
      #
      #def deep_merge!(other_hash)
      #  replace(deep_merge(other_hash))
      #end

      private

      ##
      ## MACROS
      ## these are methods used when eval'ing a value in the .json configuration
      ##

      #
      # inserts the contents of a file
      #
      def file(filename)
        filepath = Path.find_file(name, filename)
        if filepath
          File.read(filepath)
        else
          log0('no such file, "%s"' % filename)
          ""
        end
      end

    end # class
  end # module
end # module