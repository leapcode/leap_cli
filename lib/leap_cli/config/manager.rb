require 'oj'
require 'yaml'

module LeapCli
  module Config
    class Manager

      attr_reader :services, :tags, :nodes

      ##
      ## IMPORT EXPORT
      ##

      #
      # load .json configuration files
      #
      def load(dir)
        @services = load_all_json("#{dir}/services/*.json", :tag)
        @tags     = load_all_json("#{dir}/tags/*.json", :tag)
        @common   = load_all_json("#{dir}/common.json", :tag)['common']
        @nodes    = load_all_json("#{dir}/nodes/*.json", :node)
        @nodes.each do |name, node|
          @nodes[name] = apply_inheritance(node)
        end
      end

      #
      # save compiled hiera .yaml files
      #
      def export(dir)
        Dir.glob(dir + '/*.yaml').each do |f|
          File.unlink(f)
        end
        @nodes.each do |name, node|
          # not sure if people will approve of this change:
          # File.open("#{dir}/#{name}.#{node.domain_internal}.yaml", 'w') do |f|
          File.open("#{dir}/#{name}.yaml", 'w') do |f|
            f.write node.to_yaml
          end
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

        node_list = Config::List.new
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
            node_list << nodes_for_name(filter)
          end
        end
        return node_list
      end

      ##
      ## CLASS METHODS
      ##

      #def self.manager
      #  @manager ||= begin
      #    manager = ConfigManager.new
      #    manager.load(Path.provider)
      #    manager
      #  end
      #end

      #def self.filter(filters); manager.filter(filters); end
      #def self.nodes; manager.nodes; end
      #def self.services; manager.services; end
      #def self.tags; manager.tags; end

      private

      def load_all_json(pattern, config_type = :class)
        results = Config::List.new
        Dir.glob(pattern).each do |filename|
          obj = load_json(filename, config_type)
          if obj
            name = File.basename(filename).sub(/\.json$/,'')
            obj['name'] = name
            results[name] = obj
          end
        end
        results
      end

      def load_json(filename, config_type)
        log2 { filename.sub(/^#{Regexp.escape(Path.root)}/,'') }

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

        # parse json, and flatten hash
        begin
          hash = Oj.load(buffer.string) || {}
        rescue SyntaxError => exc
          log0 'Error in file "%s":' % filename
          log0 exc.to_s
          return nil
        end
        config = config_type == :node ? Node.new(self) : Tag.new(self)
        config.deep_merge!(hash)
        return config
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
      # makes this node inherit options from the common, service, and tag json files.
      #
      # - takes a hash
      # - returns a Node object.
      #
      def apply_inheritance(node)
        new_hash = Node.new(self)
        #new_node = Node.new(self)

        # inherit from common
        new_hash.deep_merge!(@common)

        # inherit from services
        if node['services']
          node['services'].sort.each do |node_service|
            service = @services[node_service]
            if service.nil?
              log0('Error in node "%s": the service "%s" does not exist.' % [node['name'], node_service])
            else
              new_hash.deep_merge!(service)
              service.nodes << new_hash
            end
          end
        end

        # inherit from tags
        if node['tags']
          node['tags'].sort.each do |node_tag|
            tag = @tags[node_tag]
            if tag.nil?
              log0('Error in node "%s": the tag "%s" does not exist.' % [node['name'], node_tag])
            else
              new_hash.deep_merge!(tag)
              tag.nodes << new_hash
            end
          end
        end

        # inherit from node
        new_hash.deep_merge!(node)

        # typecast full hash tree to type Node
        #new_node.clone_from_plain_hash!(new_hash)

        return new_hash
      end

      #
      # returns a set of nodes corresponding to a single name, where name could be a node name, service name, or tag name.
      #
      def nodes_for_name(name)
        if node = self.nodes[name]
          Config::List.new(node)
        elsif service = self.services[name]
          service.nodes
        elsif tag = self.tags[name]
          tag.nodes
        end
      end

    end
  end
end
