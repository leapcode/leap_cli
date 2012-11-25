require 'json/pure'

module LeapCli
  module Config

    #
    # A class to manage all the objects in all the configuration files.
    #
    class Manager

      attr_reader :services, :tags, :nodes, :provider, :common, :secrets

      ##
      ## IMPORT EXPORT
      ##

      #
      # load .json configuration files
      #
      def load
        @provider_dir = Path.provider

        # load base
        base_services = load_all_json(Path.named_path([:service_config, '*'], Path.provider_base))
        base_tags     = load_all_json(Path.named_path([:tag_config, '*'], Path.provider_base))
        base_common   = load_json(Path.named_path(:common_config, Path.provider_base))
        base_provider = load_json(Path.named_path(:provider_config, Path.provider_base))

        # load provider
        provider_path = Path.named_path(:provider_config, @provider_dir)
        common_path = Path.named_path(:common_config, @provider_dir)
        Util::assert_files_exist!(provider_path, common_path)
        @services = load_all_json(Path.named_path([:service_config, '*'], @provider_dir))
        @tags     = load_all_json(Path.named_path([:tag_config, '*'],     @provider_dir))
        @nodes    = load_all_json(Path.named_path([:node_config, '*'],    @provider_dir))
        @common   = load_json(common_path)
        @provider = load_json(provider_path)
        @secrets  = load_json(Path.named_path(:secrets_config,  @provider_dir))

        # inherit
        @services.inherit_from! base_services
        @tags.inherit_from!     base_tags
        @common.inherit_from!   base_common
        @provider.inherit_from! base_provider
        @nodes.each do |name, node|
          @nodes[name] = apply_inheritance(node)
        end

        # validate
        validate_provider(@provider)
      end

      #
      # save compiled hiera .yaml files
      #
      def export_nodes
        existing_hiera = Dir.glob(Path.named_path([:hiera, '*'], @provider_dir))
        existing_files = Dir.glob(Path.named_path([:node_files_dir, '*'], @provider_dir))
        updated_hiera = []
        updated_files = []
        self.each_node do |node|
          filepath = Path.named_path([:node_files_dir, node.name], @provider_dir)
          updated_files << filepath
          hierapath = Path.named_path([:hiera, node.name], @provider_dir)
          updated_hiera << hierapath
          Util::write_file!(hierapath, node.dump)
        end
        (existing_hiera - updated_hiera).each do |filepath|
          Util::remove_file!(filepath)
        end
        (existing_files - updated_files).each do |filepath|
          Util::remove_directory!(filepath)
        end
      end

      def export_secrets(destination_file = nil)
        if @secrets.any?
          file_path = destination_file || Path.named_path(:secrets_config, @provider_dir)
          Util.write_file!(file_path, @secrets.dump_json + "\n")
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
        Util::assert! node_list.any?, "Could not match any nodes from '#{filters}'"
        return node_list
      end

      #
      # returns a single Config::Object that corresponds to a Node.
      #
      def node(name)
        nodes[name]
      end

      #
      # yields each node, in sorted order
      #
      def each_node(&block)
        nodes.each_node &block
      end

      private

      def load_all_json(pattern)
        results = Config::ObjectList.new
        Dir.glob(pattern).each do |filename|
          obj = load_json(filename)
          if obj
            name = File.basename(filename).sub(/\.json$/,'')
            obj['name'] ||= name
            results[name] = obj
          end
        end
        results
      end

      def load_json(filename)
        if !File.exists?(filename)
          return Config::Object.new(self)
        end

        log :loading, filename, 2

        #
        # read file, strip out comments
        # (File.read(filename) would be faster, but we like ability to have comments)
        #
        buffer = StringIO.new
        File.open(filename) do |f|
          while (line = f.gets)
            next if line =~ /^\s*#/
            buffer << line
          end
        end

        # parse json
        begin
          hash = JSON.parse(buffer.string, :object_class => Hash, :array_class => Array) || {}
        rescue SyntaxError => exc
          log 0, :error, 'in file "%s":' % filename
          log 0, exc.to_s, :indent => 1
          return nil
        end
        object = Config::Object.new(self)
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
        new_node = Config::Object.new(self)
        name = node.name

        # inherit from common
        new_node.deep_merge!(@common)

        # inherit from services
        if node['services']
          node['services'].to_a.sort.each do |node_service|
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
          node['tags'].to_a.sort.each do |node_tag|
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

      #
      # TODO: apply JSON spec
      #
      PRIVATE_IP_RANGES = /(^127\.0\.0\.1)|(^10\.)|(^172\.1[6-9]\.)|(^172\.2[0-9]\.)|(^172\.3[0-1]\.)|(^192\.168\.)/
      def validate_provider(provider)
        Util::assert! provider.vagrant.network =~ PRIVATE_IP_RANGES do
          log 0, :error, 'in provider.json: vagrant.network is not a local private network'
        end
      end

    end
  end
end
