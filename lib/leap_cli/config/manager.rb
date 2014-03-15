require 'json/pure'

if $ruby_version < [1,9]
  require 'iconv'
end

module LeapCli
  module Config

    #
    # A class to manage all the objects in all the configuration files.
    #
    class Manager

      ##
      ## ATTRIBUTES
      ##

      attr_reader :services, :tags, :nodes, :provider, :providers, :common, :secrets
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
      def environments
        @environments ||= [nil] + self.tags.collect {|name, tag| tag['environment']}.compact
      end

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
        @base_tags     = load_all_json(Path.named_path([:tag_config, '*'], Path.provider_base), Config::Tag)
        @base_common   = load_json(Path.named_path(:common_config, Path.provider_base), Config::Object)
        @base_provider = load_json(Path.named_path(:provider_config, Path.provider_base), Config::Provider)

        # load provider
        provider_path = Path.named_path(:provider_config, @provider_dir)
        common_path = Path.named_path(:common_config, @provider_dir)
        Util::assert_files_exist!(provider_path, common_path)
        @services = load_all_json(Path.named_path([:service_config, '*'], @provider_dir), Config::Tag)
        @tags     = load_all_json(Path.named_path([:tag_config, '*'],     @provider_dir), Config::Tag)
        @nodes    = load_all_json(Path.named_path([:node_config, '*'],    @provider_dir), Config::Node)
        @common   = load_json(common_path, Config::Object)
        @provider = load_json(provider_path, Config::Provider)
        @secrets  = load_json(Path.named_path(:secrets_config,  @provider_dir), Config::Secrets)

        ### BEGIN HACK
        ### remove this after it is likely that no one has any old-style secrets.json
        if @secrets['webapp_secret_token']
          @secrets = Config::Secrets.new
          Util::log :warning, "Creating all new secrets.json (new version is scoped by environment). Make sure to do a full deploy so that new secrets take effect."
        end
        ### END HACK

        # inherit
        @services.inherit_from! base_services
        @tags.inherit_from!     base_tags
        @common.inherit_from!   base_common
        @provider.inherit_from! base_provider
        @nodes.each do |name, node|
          Util::assert! name =~ /^[0-9a-z-]+$/, "Illegal character(s) used in node name '#{name}'"
          @nodes[name] = apply_inheritance(node)
        end

        unless options[:include_disabled]
          remove_disabled_nodes
        end

        # load optional environment specific providers
        validate_provider(@provider)
        @providers = {}
        environments.each do |env|
          if Path.defined?(:provider_env_config)
            provider_path = Path.named_path([:provider_env_config, env], @provider_dir)
            providers[env] = load_json(provider_path, Config::Provider)
            providers[env].inherit_from! @provider
            validate_provider(providers[env])
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
      def filter(filters)
        if filters.empty?
          return nodes
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

      def reload_node(node)
        @nodes[node.name] = apply_inheritance(node)
      end

      private

      def load_all_json(pattern, object_class)
        results = Config::ObjectList.new
        Dir.glob(pattern).each do |filename|
          obj = load_json(filename, object_class)
          if obj
            name = File.basename(filename).sub(/\.json$/,'')
            obj['name'] ||= name
            results[name] = obj
          end
        end
        results
      end

      def load_json(filename, object_class)
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
        File.open(filename, "rb") do |f|
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
      def apply_inheritance(node)
        new_node = Config::Node.new(self)
        name = node.name

        # inherit from common
        new_node.deep_merge!(@common)

        # inherit from services
        if node['services']
          node['services'].to_a.each do |node_service|
            service = @services[node_service]
            if service.nil?
              log 0, :error, 'in node "%s": the service "%s" does not exist.' % [node['name'], node_service]
            else
              new_node.deep_merge!(service)
              service.node_list.add(name, new_node)
            end
          end
        end

        # inherit from tags
        if node.vagrant?
          node['tags'] = (node['tags'] || []).to_a + ['local']
        end
        if node['tags']
          node['tags'].to_a.each do |node_tag|
            tag = @tags[node_tag]
            if tag.nil?
              log 0, :error, 'in node "%s": the tag "%s" does not exist.' % [node['name'], node_tag]
            else
              new_node.deep_merge!(tag)
              tag.node_list.add(name, new_node)
            end
          end
        end

        # inherit from node
        new_node.deep_merge!(node)
        return new_node
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
                @services[node_service].node_list.delete(node.name)
              end
            end
            if node['tags']
              node['tags'].to_a.each do |node_tag|
                @tags[node_tag].node_list.delete(node.name)
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

    end
  end
end
