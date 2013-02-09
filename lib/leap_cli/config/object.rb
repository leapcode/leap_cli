require 'erb'
require 'json/pure'  # pure ruby implementation is required for our sorted trick to work.

$KCODE = 'UTF8' unless RUBY_VERSION > "1.9.0"
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
      alias :global :manager

      def initialize(manager=nil, node=nil)
        # keep a global pointer around to the config manager. used a lot in the eval strings and templates
        # (which are evaluated in the context of Config::Object)
        @manager = manager

        # an object that is a node as @node equal to self, otherwise all the child objects point back to the top level node.
        @node = node || self
      end

      #
      # We use pure ruby yaml exporter ya2yaml instead of SYCK or PSYCH because it
      # allows us greater compatibility regardless of installed ruby version and
      # greater control over how the yaml is exported (sorted keys, in particular).
      #
      def dump
        evaluate
        ya2yaml(:syck_compatible => true)
      end

      def dump_json
        evaluate
        generate_json(self)
      end

      def evaluate
        evaluate_everything
        late_evaluate_everything
      end

      ##
      ## FETCHING VALUES
      ##

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

      #
      # Like a normal Hash#[], except:
      #
      # (1) lazily eval dynamic values when we encounter them. (i.e. strings that start with "= ")
      #
      # (2) support for nested references in a single string (e.g. ['a.b'] is the same as ['a']['b'])
      #     the dot path is always absolute, starting at the top-most object.
      #
      def get!(key)
        key = key.to_s
        if key =~ /\./
          # for keys with with '.' in them, we start from the root object (@node).
          keys = key.split('.')
          value = @node.get!(keys.first)
          if value.is_a? Config::Object
            value.get!(keys[1..-1].join('.'))
          else
            value
          end
        elsif self.has_key?(key)
          evaluate_key(key)
        else
          raise NoMethodError.new(key, "No method '#{key}' for #{self.class}")
        end
      end

      ##
      ## COPYING
      ##

      #
      # a deep (recursive) merge with another Config::Object.
      #
      # if prefer_self is set to true, the value from self will be picked when there is a conflict
      # that cannot be merged.
      #
      def deep_merge!(object, prefer_self=false)
        object.each do |key,new_value|
          old_value = self.fetch key, nil

          # clean up boolean
          new_value = true  if new_value == "true"
          new_value = false if new_value == "false"
          old_value = true  if old_value == "true"
          old_value = false if old_value == "false"

          # merge hashes
          if old_value.is_a?(Hash) || new_value.is_a?(Hash)
            value = Config::Object.new(@manager, @node)
            old_value.is_a?(Hash) ? value.deep_merge!(old_value) : (value[key] = old_value if old_value.any?)
            new_value.is_a?(Hash) ? value.deep_merge!(new_value, prefer_self) : (value[key] = new_value if new_value.any?)

          # merge arrays
          elsif old_value.is_a?(Array) || new_value.is_a?(Array)
            value = []
            old_value.is_a?(Array) ? value += old_value : value << old_value
            new_value.is_a?(Array) ? value += new_value : value << new_value
            value = value.compact.uniq

          # merge nil
          elsif new_value.nil?
            value = old_value
          elsif old_value.nil?
            value = new_value

          # merge boolean
          elsif old_value.is_a?(Boolean) && new_value.is_a?(Boolean)
            # FalseClass and TrueClass are different classes, so we must handle them separately
            if prefer_self
              value = old_value
            else
              value = new_value
            end

          # catch errors
          elsif old_value.class != new_value.class
            raise 'Type mismatch. Cannot merge %s (%s) with %s (%s). Key is "%s", name is "%s".' % [
              old_value.inspect, old_value.class,
              new_value.inspect, new_value.class,
              key, self.class
            ]

          # merge strings and numbers
          else
            if prefer_self
              value = old_value
            else
              value = new_value
            end
          end

          # save value
          self[key] = value
        end
        self
      end

      #
      # like a reverse deep merge
      # (self takes precedence)
      #
      def inherit_from!(object)
        self.deep_merge!(object, true)
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
      # returns a list of nodes that match similar production level (production, local, testing, etc)
      #
      def nodes_like_me
        nodes[:production => @node.production, :local => @node.local]
      end

      class FileMissing < Exception
        attr_accessor :path, :options
        def initialize(path, options={})
          @path = path
          @options = options
        end
        def to_s
          @path
        end
      end

      #
      # inserts the contents of a file
      #
      def file(filename, options={})
        if filename.is_a? Symbol
          filename = [filename, @node.name]
        end
        filepath = Path.find_file(filename)
        if filepath
          if filepath =~ /\.erb$/
            ERB.new(File.read(filepath), nil, '%<>').result(binding)
          else
            File.read(filepath)
          end
        else
          raise FileMissing.new(Path.named_path(filename), options)
          ""
        end
      end

      #
      # like #file, but allow missing files
      #
      def try_file(filename)
        return file(filename)
      rescue FileMissing
        return nil
      end

      #
      # returns what the file path will be, once the file is rsynced to the server.
      # an internal list of discovered file paths is saved, in order to rsync these files when needed.
      #
      # notes:
      #
      # * argument 'path' is relative to Path.provider/files or Path.provider_base/files
      # * the path returned by this method is absolute
      # * the path stored for use later by rsync is relative to Path.provider
      # * if the path does not exist locally, but exists in provider_base, then the default file from
      #   provider_base is copied locally.
      #
      def file_path(path)
        if path.is_a? Symbol
          path = [path, @node.name]
        end
        actual_path = Path.find_file(path)
        if actual_path.nil?
          nil
        else
          if actual_path =~ /^#{Regexp.escape(Path.provider_base)}/
            # if file is under Path.provider_base, we must copy the default file to
            # to Path.provider in order for rsync to be able to sync the file.
            local_provider_path = actual_path.sub(/^#{Regexp.escape(Path.provider_base)}/, Path.provider)
            FileUtils.cp_r actual_path, local_provider_path
            Util.log :created, Path.relative_path(local_provider_path)
            actual_path = local_provider_path
          end
          if Dir.exists?(actual_path) && actual_path !~ /\/$/
            actual_path += '/' # ensure directories end with /, important for building rsync command
          end
          relative_path = Path.relative_path(actual_path)
          @node.file_paths << relative_path
          @node.manager.provider.hiera_sync_destination + '/' + relative_path
        end
      end

      #
      # inserts a named secret, generating it if needed.
      #
      # manager.export_secrets should be called later to capture any newly generated secrets.
      #
      def secret(name, length=32)
        @manager.secrets.set(name, Util::Secret.generate(length))
      end

      #
      # return a fingerprint for a x509 certificate
      #
      def fingerprint(filename)
        "SHA256: " + X509.fingerprint("SHA256", Path.named_path(filename))
      end

      #
      # records the list of hosts that are encountered for this node
      #
      def hostnames(nodes)
        @referenced_nodes ||= ObjectList.new
        if nodes.is_a? Config::Object
          nodes = ObjectList.new nodes
        end
        nodes.each_node do |node|
          @referenced_nodes[node.name] = node
        end
        nodes.values.collect do |node|
          node.domain.name
        end
      end

      #
      # generates entries needed for updating /etc/hosts on a node, but only including the IPs of the
      # other nodes we have encountered.
      #
      def hosts_file
        return nil unless @referenced_nodes
        entries = []
        @referenced_nodes.each_node do |node|
          entries << "#{node.ip_address}    #{node.name} #{node.domain.internal} #{node.domain.full}"
        end
        entries.join("\n")
      end

      def known_hosts_file
        return nil unless @referenced_nodes
        entries = []
        @referenced_nodes.each_node do |node|
          hostnames = [node.name, node.domain.internal, node.domain.full, node.ip_address].join(',')
          pub_key   = Util::read_file([:node_ssh_pub_key,node.name])
          if pub_key
            entries << [hostnames, pub_key].join(' ')
          end
        end
        entries.join("\n")
      end

      protected

      #
      # walks the object tree, eval'ing all the attributes that are dynamic ruby (e.g. value starts with '= ')
      #
      def evaluate_everything
        keys.each do |key|
          obj = evaluate_key(key)
          if obj.is_a? Config::Object
            obj.evaluate_everything
          end
        end
      end

      #
      # some keys need to be evaluated 'late', after all the other keys have been evaluated.
      #
      def late_evaluate_everything
        if @late_eval_list
          @late_eval_list.each do |key, value|
            self[key] = evaluate_now(key, value)
          end
        end
        values.each do |obj|
          if obj.is_a? Config::Object
            obj.late_evaluate_everything
          end
        end
      end

      private

      #
      # fetches the value for the key, evaluating the value as ruby if it begins with '='
      #
      def evaluate_key(key)
        value = fetch(key, nil)
        if !value.is_a?(String)
          value
        else
          if value =~ /^=> (.*)$/
            value = evaluate_later(key, $1)
          elsif value =~ /^= (.*)$/
            value = evaluate_now(key, $1)
          end
          self[key] = value
          value
        end
      end

      def evaluate_later(key, value)
        @late_eval_list ||= []
        @late_eval_list << [key, value]
        '<evaluate later>'
      end

      def evaluate_now(key, value)
        return @node.instance_eval(value)
      rescue SystemStackError => exc
        Util::log 0, :error, "while evaluating node '#{@node.name}'"
        Util::log 0, "offending key: #{key}", :indent => 1
        Util::log 0, "offending string: #{value}", :indent => 1
        Util::log 0, "STACK OVERFLOW, BAILING OUT. There must be an eval loop of death (variables with circular dependencies).", :indent => 1
        raise SystemExit.new()
      rescue FileMissing => exc
        Util::bail! do
          if exc.options[:missing]
            Util::log :missing, exc.options[:missing].gsub('$node', @node.name)
          else
            Util::log :error, "while evaluating node '#{@node.name}'"
            Util::log "offending key: #{key}", :indent => 1
            Util::log "offending string: #{value}", :indent => 1
            Util::log "error message: no file '#{exc}'", :indent => 1
          end
        end
      rescue SyntaxError, StandardError => exc
        Util::bail! do
          Util::log :error, "while evaluating node '#{@node.name}'"
          Util::log "offending key: #{key}", :indent => 1
          Util::log "offending string: #{value}", :indent => 1
          Util::log "error message: #{exc.inspect}", :indent => 1
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