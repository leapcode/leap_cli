# encoding: utf-8

require 'json/pure'

if $ruby_version < [1,9]
  require 'iconv'
end

module LeapCli
  module Config

    class Environment
      attr_accessor :services, :tags, :provider
    end

    #
    # A class to manage all the objects in all the configuration files.
    #
    class Manager

      def initialize
        @environments = {} # hash of `Environment` objects, keyed by name.

        # load macros and other custom ruby in provider base
        platform_ruby_files = Dir[Path.provider_base + '/lib/*.rb']
        if platform_ruby_files.any?
          $: << Path.provider_base + '/lib'
          platform_ruby_files.each do |rb_file|
            require rb_file
          end
        end
        Config::Object.send(:include, LeapCli::Macro)
      end

      ##
      ## ATTRIBUTES
      ##

      attr_reader :nodes, :common, :secrets
      attr_reader :base_services, :base_tags, :base_provider, :base_common

      #
      # returns the Hash of the contents of facts.json
      #
      def facts
        @facts ||= JSON.parse(Util.read_file(:facts) || "{}")
      end

      #
      # returns an Array of all the environments defined for this provider.
      # the returned array includes nil (for the default environment)
      #
      def environment_names
        @environment_names ||= [nil] + env.tags.collect {|name, tag| tag['environment']}.compact
      end

      #
      # Returns the appropriate environment variable
      #
      def env(env=nil)
        env ||= 'default'
        e = @environments[env] ||= Environment.new
        yield e if block_given?
        e
      end

      def services; env('default').services; end
      def tags; env('default').tags; end
      def provider; env('default').provider; end

      ##
      ## IMPORT EXPORT
      ##

      #
      # load .json configuration files
      #
      def load(options = {})
        @provider_dir = Path.provider

        # load base
        @base_services = load_all_json(Path.named_path([:service_config, '*'], Path.provider_base), Config::Tag)
        @base_tags     = load_all_json(Path.named_path([:tag_config, '*'],     Path.provider_base), Config::Tag)
        @base_common   = load_json(    Path.named_path(:common_config,         Path.provider_base), Config::Object)
        @base_provider = load_json(    Path.named_path(:provider_config,       Path.provider_base), Config::Provider)

        # load provider
        @nodes    = load_all_json(Path.named_path([:node_config, '*'],  @provider_dir), Config::Node)
        @common   = load_json(    Path.named_path(:common_config,       @provider_dir), Config::Object)
        @secrets  = load_json(    Path.named_path(:secrets_config,      @provider_dir), Config::Secrets)
        @common.inherit_from! @base_common

        # load provider services, tags, and provider.json, DEFAULT environment
        log 3, :loading, 'default environment.........'
        env('default') do |e|
          e.services = load_all_json(Path.named_path([:service_config, '*'], @provider_dir), Config::Tag, :no_dots => true)
          e.tags     = load_all_json(Path.named_path([:tag_config, '*'],     @provider_dir), Config::Tag, :no_dots => true)
          e.provider = load_json(    Path.named_path(:provider_config,       @provider_dir), Config::Provider, :assert => true)
          e.services.inherit_from! @base_services
          e.tags.inherit_from!     @base_tags
          e.provider.inherit_from! @base_provider
          validate_provider(e.provider)
        end

        # load provider services, tags, and provider.json, OTHER environments
        environment_names.each do |ename|
          next unless ename
          log 3, :loading, '%s environment.........' % ename
          env(ename) do |e|
            e.services = load_all_json(Path.named_path([:service_env_config, '*', ename], @provider_dir), Config::Tag)
            e.tags     = load_all_json(Path.named_path([:tag_env_config, '*', ename],     @provider_dir), Config::Tag)
            e.provider = load_json(    Path.named_path([:provider_env_config, ename],     @provider_dir), Config::Provider)
            e.services.inherit_from! env.services
            e.tags.inherit_from!     env.tags
            e.provider.inherit_from! env.provider
            validate_provider(e.provider)
          end
        end

        # apply inheritance
        @nodes.each do |name, node|
          Util::assert! name =~ /^[0-9a-z-]+$/, "Illegal character(s) used in node name '#{name}'"
          @nodes[name] = apply_inheritance(node)
        end

        # remove disabled nodes
        unless options[:include_disabled]
          remove_disabled_nodes
        end

        # apply control files
        @nodes.each do |name, node|
          control_files(node).each do |file|
            node.instance_eval File.read(file), file, 1
          end
        end
      end

      #
      # save compiled hiera .yaml files
      #
      # if a node_list is specified, only update those .yaml files.
      # otherwise, update all files, destroying files that are no longer used.
      #
      def export_nodes(node_list=nil)
        updated_hiera = []
        updated_files = []
        existing_hiera = nil
        existing_files = nil

        unless node_list
          node_list = self.nodes
          existing_hiera = Dir.glob(Path.named_path([:hiera, '*'], @provider_dir))
          existing_files = Dir.glob(Path.named_path([:node_files_dir, '*'], @provider_dir))
        end

        node_list.each_node do |node|
          filepath = Path.named_path([:node_files_dir, node.name], @provider_dir)
          hierapath = Path.named_path([:hiera, node.name], @provider_dir)
          Util::write_file!(hierapath, node.dump_yaml)
          updated_files << filepath
          updated_hiera << hierapath
        end

        if @disabled_nodes
          # make disabled nodes appear as if they are still active
          @disabled_nodes.each_node do |node|
            updated_files << Path.named_path([:node_files_dir, node.name], @provider_dir)
            updated_hiera << Path.named_path([:hiera, node.name], @provider_dir)
          end
        end

        # remove files that are no longer needed
        if existing_hiera
          (existing_hiera - updated_hiera).each do |filepath|
            Util::remove_file!(filepath)
          end
        end
        if existing_files
          (existing_files - updated_files).each do |filepath|
            Util::remove_directory!(filepath)
          end
        end
      end

      def export_secrets(clean_unused_secrets = false)
        if @secrets.any?
          Util.write_file!([:secrets_config, @provider_dir], @secrets.dump_json(clean_unused_secrets) + "\n")
        end
      end

      ##
      ## FILTERING
      ##

      #
      # returns a node list consisting only of nodes that satisfy the filter criteria.
      #
      # filter: condition [condition] [condition] [+condition]
      # condition: [node_name | service_name | tag_name]
      #
      # if conditions is prefixed with +, then it works like an AND. Otherwise, it works like an OR.
      #
      # options:
      # :local -- if :local is false and the filter is empty, then local nodes are excluded.
      #
      def filter(filters, options={})
        if filters.empty?
          if options[:local] === false
            return nodes[:environment => '!local']
          else
            return nodes
          end
        end
        if filters[0] =~ /^\+/
          # don't let the first filter have a + prefix
          filters[0] = filters[0][1..-1]
        end

        node_list = Config::ObjectList.new
        filters.each do |filter|
          if filter =~ /^\+/
            keep_list = nodes_for_name(filter[1..-1])
            node_list.delete_if do |name, node|
              if keep_list[name]
                false
              else
                true
              end
            end
          else
            node_list.merge!(nodes_for_name(filter))
          end
        end
        return node_list
      end

      #
      # same as filter(), but exits if there is no matching nodes
      #
      def filter!(filters)
        node_list = filter(filters)
        Util::assert! node_list.any?, "Could not match any nodes from '#{filters.join ' '}'"
        return node_list
      end

      #
      # returns a single Config::Object that corresponds to a Node.
      #
      def node(name)
        if name =~ /\./
          # probably got a fqdn, since periods are not allowed in node names.
          # so, take the part before the first period as the node name
          name = name.split('.').first
        end
        @nodes[name]
      end

      #
      # returns a single node that is disabled
      #
      def disabled_node(name)
        @disabled_nodes[name]
      end

      #
      # yields each node, in sorted order
      #
      def each_node(&block)
        nodes.each_node &block
      end

      def reload_node!(node)
        @nodes[node.name] = apply_inheritance!(node)
      end

      #
      # returns all the partial data for the specified partial path.
      # partial path is always relative to provider root, but there must be multiple files
      # that match because provider root might be the base provider or the local provider.
      #
      def partials(partial_path)
        @partials ||= {}
        if @partials[partial_path].nil?
          [Path.provider_base, Path.provider].each do |provider_dir|
            path = File.join(provider_dir, partial_path)
            if File.exists?(path)
              @partials[partial_path] ||= []
              @partials[partial_path] << load_json(path, Config::Object)
            end
          end
          if @partials[partial_path].nil?
            raise RuntimeError, 'no such partial path `%s`' % partial_path, caller
          end
        end
        @partials[partial_path]
      end

      private

      def load_all_json(pattern, object_class, options={})
        results = Config::ObjectList.new
        Dir.glob(pattern).each do |filename|
          next if options[:no_dots] && File.basename(filename) !~ /^[^\.]*\.json$/
          obj = load_json(filename, object_class)
          if obj
            name = File.basename(filename).force_encoding('utf-8').sub(/^([^\.]+).*\.json$/,'\1')
            obj['name'] ||= name
            results[name] = obj
          end
        end
        results
      end

      def load_json(filename, object_class, options={})
        if options[:assert]
          Util::assert_files_exist!(filename)
        end
        if !File.exists?(filename)
          return object_class.new(self)
        end

        log :loading, filename, 3

        #
        # Read a JSON file, strip out comments.
        #
        # UTF8 is the default encoding for JSON, but others are allowed:
        # https://www.ietf.org/rfc/rfc4627.txt
        #
        buffer = StringIO.new
        File.open(filename, "rb", :encoding => 'UTF-8') do |f|
          while (line = f.gets)
            next if line =~ /^\s*\/\//
            buffer << line
          end
        end

        #
        # force UTF-8
        #
        if $ruby_version >= [1,9]
          string = buffer.string.force_encoding('utf-8')
        else
          string = Iconv.conv("UTF-8//IGNORE", "UTF-8", buffer.string)
        end

        # parse json
        begin
          hash = JSON.parse(string, :object_class => Hash, :array_class => Array) || {}
        rescue SyntaxError, JSON::ParserError => exc
          log 0, :error, 'in file "%s":' % filename
          log 0, exc.to_s, :indent => 1
          return nil
        end
        object = object_class.new(self)
        object.deep_merge!(hash)
        return object
      end

      #
      # remove all the nesting from a hash.
      #
      # def flatten_hash(input = {}, output = {}, options = {})
      #   input.each do |key, value|
      #     key = options[:prefix].nil? ? "#{key}" : "#{options[:prefix]}#{options[:delimiter]||"_"}#{key}"
      #     if value.is_a? Hash
      #       flatten_hash(value, output, :prefix => key, :delimiter => options[:delimiter])
      #     else
      #       output[key]  = value
      #     end
      #   end
      #   output.replace(input)
      #   output
      # end

      #
      # makes a node inherit options from appropriate the common, service, and tag json files.
      #
      def apply_inheritance(node, throw_exceptions=false)
        new_node = Config::Node.new(self)
        name = node.name

        # Guess the environment of the node from the tag names.
        # (Technically, this is wrong: a tag that sets the environment might not be
        #  named the same as the environment. This code assumes that it is).
        node_env = self.env
        if node['tags']
          node['tags'].to_a.each do |tag|
            if self.environment_names.include?(tag)
              node_env = self.env(tag)
            end
          end
        end

        # inherit from common
        new_node.deep_merge!(@common)

        # inherit from services
        if node['services']
          node['services'].to_a.each do |node_service|
            service = node_env.services[node_service]
            if service.nil?
              msg = 'in node "%s": the service "%s" does not exist.' % [node['name'], node_service]
              log 0, :error, msg
              raise LeapCli::ConfigError.new(node, "error " + msg) if throw_exceptions
            else
              new_node.deep_merge!(service)
              self.services[node_service].node_list.add(name, new_node)
            end
          end
        end

        # inherit from tags
        if node.vagrant?
          node['tags'] = (node['tags'] || []).to_a + ['local']
        end
        if node['tags']
          node['tags'].to_a.each do |node_tag|
            tag = node_env.tags[node_tag]
            if tag.nil?
              msg = 'in node "%s": the tag "%s" does not exist.' % [node['name'], node_tag]
              log 0, :error, msg
              raise LeapCli::ConfigError.new(node, "error " + msg) if throw_exceptions
            else
              new_node.deep_merge!(tag)
              self.tags[node_tag].node_list.add(name, new_node)
            end
          end
        end

        # inherit from node
        new_node.deep_merge!(node)
        return new_node
      end

      def apply_inheritance!(node)
        apply_inheritance(node, true)
      end

      def remove_disabled_nodes
        @disabled_nodes = Config::ObjectList.new
        @nodes.each do |name, node|
          unless node.enabled
            log 2, :skipping, "disabled node #{name}."
            @nodes.delete(name)
            @disabled_nodes[name] = node
            if node['services']
              node['services'].to_a.each do |node_service|
                self.services[node_service].node_list.delete(node.name)
              end
            end
            if node['tags']
              node['tags'].to_a.each do |node_tag|
                self.tags[node_tag].node_list.delete(node.name)
              end
            end
          end
        end
      end


      #
      # returns a set of nodes corresponding to a single name, where name could be a node name, service name, or tag name.
      #
      def nodes_for_name(name)
        if node = self.nodes[name]
          Config::ObjectList.new(node)
        elsif service = self.services[name]
          service.node_list
        elsif tag = self.tags[name]
          tag.node_list
        else
          {}
        end
      end

      def validate_provider(provider)
        # nothing yet.
      end

      #
      # returns a list of 'control' files for this node.
      # a control file is like a service or a tag JSON file, but it contains
      # raw ruby code that gets evaluated in the context of the node.
      # Yes, this entirely breaks our functional programming model
      # for JSON generation.
      #
      def control_files(node)
        files = []
        [Path.provider_base, @provider_dir].each do |provider_dir|
          [['services', :service_config], ['tags', :tag_config]].each do |attribute, path_sym|
            node[attribute].each do |attr_value|
              path = Path.named_path([path_sym, "#{attr_value}.rb"], provider_dir).sub(/\.json$/,'')
              if File.exists?(path)
                files << path
              end
            end
          end
        end
        return files
      end

    end
  end
end
