require 'erb'
require 'json/pure'  # pure ruby implementation is required for our sorted trick to work.

$KCODE = 'UTF8'
require 'ya2yaml' # pure ruby yaml

module LeapCli
  module Config
    #
    # This class represents the configuration for a single node, service, or tag.
    # Also, all the nested hashes are also of this type.
    #
    # It is called 'object' because it corresponds to an Object in JSON.
    #
    class Object < Hash

      attr_reader :node
      attr_reader :manager
      attr_reader :node_list
      alias :global :manager

      def initialize(manager=nil, node=nil)
        # keep a global pointer around to the config manager. used a lot in the eval strings and templates
        # (which are evaluated in the context of Config::Object)
        @manager = manager

        # an object that is a node as @node equal to self, otherwise all the child objects point back to the top level node.
        @node = node || self

        # this is only used by Config::Objects that correspond to services or tags.
        @node_list = Config::ObjectList.new
      end

      # We use pure ruby yaml exporter ya2yaml instead of SYCK or PSYCH because it
      # allows us greater compatibility regardless of installed ruby version and
      # greater control over how the yaml is exported.
      #
      def dump
        self.ya2yaml(:syck_compatible => true)
      end

      ##
      ## FETCHING VALUES
      ##

      #
      # like a normal hash [], except:
      # * lazily eval dynamic values when we encounter them.
      # * support for nested hashes (e.g. ['a.b'] is the same as ['a']['b'])
      #
      def [](key)
        get(key)
      end

      #
      # make hash addressable like an object (e.g. obj['name'] available as obj.name)
      #
      def method_missing(method, *args, &block)
        get!(method)
      end

      def get(key)
        begin
          get!(key)
        rescue NoMethodError
          nil
        end
      end

      def get!(key)
        key = key.to_s
        if key =~ /\./
          keys = key.split('.')
          value = get!(keys.first)
          if value.is_a? Config::Object
            value.get!(keys[1..-1])
          else
            value
          end
        elsif self.has_key?(key)
          evaluate_value(key)
        elsif @node != self
          @node.get!(key)
        else
          raise NoMethodError.new(key, "No method '#{key}' for #{self.class}")
        end
      end

      ##
      ## COPYING
      ##

      #
      # Make a copy of ourselves, except only including the specified keys.
      #
      # Also, the result is flattened to a single hash, so a key of 'a.b' becomes 'a_b'
      #
      def pick(*keys)
        keys.map(&:to_s).inject(Config::Object.new(@manager,@node)) do |hsh, key|
          value = self.get(key)
          if value
            hsh[key.gsub('.','_')] = value
          end
          hsh
        end
      end

      #
      # a deep (recursive) merge with another Config::Object.
      #
      def deep_merge!(object)
        object.each do |key,new_value|
          old_value = self[key]
          if old_value.is_a?(Hash) || new_value.is_a?(Hash)
            # merge hashes
            value = Config::Object.new(@manager, @node)
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

      private

      #
      # fetches the value for the key, evaluating the value as ruby if it begins with '='
      #
      def evaluate_value(key)
        value = fetch(key, nil)
        if value.is_a? Array
          value
        elsif value.nil?
          nil
        else
          if value =~ /^= (.*)$/
            begin
              value = eval($1, self.send(:binding))
              self[key] = value
            rescue SystemStackError => exc
              puts "STACK OVERFLOW, BAILING OUT"
              puts "There must be an eval loop of death (variables with circular dependencies). This is the offending string:"
              puts
              puts "    #{$1}"
              puts
              raise SystemExit.new()
            rescue StandardError => exc
              puts "Eval error in '#{@node.name}'"
              puts "   string: #{$1}"
              puts "   error: #{exc.name}"
            end
          end
          value
        end
      end

      ##
      ## MACROS
      ## these are methods used when eval'ing a value in the .json configuration
      ##

      #
      # the list of all the nodes
      #
      def nodes
        global.nodes
      end

      #
      # inserts the contents of a file
      #
      def file(filename)
        filepath = Path.find_file(@node.name, filename)
        if filepath
          if filepath =~ /\.erb$/
            ERB.new(File.read(filepath), nil, '%<>').result(binding)
          else
            File.read(filepath)
          end
        else
          log0('no such file, "%s"' % filename)
          ""
        end
      end

      #
      # Output json from ruby objects in such a manner that all the hashes and arrays are output in alphanumeric sorted order.
      # This is required so that our generated configs don't throw puppet or git for a tizzy fit.
      #
      # Beware: some hacky stuff ahead.
      #
      # This relies on the pure ruby implementation of JSON.generate (i.e. require 'json/pure')
      # see https://github.com/flori/json/blob/master/lib/json/pure/generator.rb
      #
      # The Oj way that we are not using: Oj.dump(obj, :mode => :compat, :indent => 2)
      #
      def generate_json(obj)

        # modify hash and array
        Hash.class_eval do
          alias_method :each_without_sort, :each
          def each(&block)
            keys.sort {|a,b| a.to_s <=> b.to_s }.each do |key|
              yield key, self[key]
            end
          end
        end
        Array.class_eval do
          alias_method :each_without_sort, :each
          def each(&block)
            sort {|a,b| a.to_s <=> b.to_s }.each_without_sort &block
          end
        end

        # generate json
        return_value = JSON.pretty_generate(obj)

        # restore hash and array
        Hash.class_eval  {alias_method :each, :each_without_sort}
        Array.class_eval {alias_method :each, :each_without_sort}

        return return_value
      end

    end # class
  end # module
end # module