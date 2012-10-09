require 'oj'
require 'yaml'

module LeapCli

  class ConfigManager

    attr_reader :services, :tags, :nodes

    ##
    ## IMPORT EXPORT
    ##

    #
    # load .json configuration files
    #
    def load(dir)
      @services = load_all_json("#{dir}/services/*.json")
      @tags     = load_all_json("#{dir}/tags/*.json")
      @common   = load_all_json("#{dir}/common.json")['common']
      @nodes    = load_all_json("#{dir}/nodes/*.json", :node)
      @nodes.each do |name, node|
        apply_inheritance(node)
      end
      @nodes.each do |name, node|
        node.each {|key,value| node[key] } # force evaluation of dynamic values
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
        File.open("#{dir}/#{name}.#{node.domain_internal}.yaml", 'w') do |f|
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

      node_list = ConfigList.new
      filters.each do |filter|
        if filter =~ /^\+/
          keep_list = nodes_for_filter(filter[1..-1])
          node_list.delete_if do |name, node|
            if keep_list[name]
              false
            else
              true
            end
          end
        else
          node_list << nodes_for_filter(filter)
        end
      end
      return node_list
    end

    ##
    ## CLASS METHODS
    ##

    def self.manager
      @manager ||= begin
        manager = ConfigManager.new
        manager.load(Path.provider)
        manager
      end
    end

    def self.filter(filters); manager.filter(filters); end
    def self.nodes; manager.nodes; end
    def self.services; manager.services; end
    def self.tags; manager.tags; end

    private

    def load_all_json(pattern, config_type = :class)
      results = ConfigList.new
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
      return flatten_hash(hash, Config.new(config_type, self))
    end

    #
    # remove all the nesting from a hash.
    #
    def flatten_hash(input = {}, output = {}, options = {})
      input.each do |key, value|
        key = options[:prefix].nil? ? "#{key}" : "#{options[:prefix]}#{options[:delimiter]||"_"}#{key}"
        if value.is_a? Hash
          flatten_hash(value, output, :prefix => key, :delimiter => options[:delimiter])
        else
          output[key]  = value
        end
      end
      output
    end

    #
    # makes this node inherit options from the common, service, and tag json files.
    #
    def apply_inheritance(node)
      new_node = Config.new(:node, self)
      new_node.merge!(@common)
      if node['services']
        node['services'].sort.each do |node_service|
          service = @services[node_service]
          if service.nil?
            log0('Error in node "%s": the service "%s" does not exist.' % [node['name'], node_service])
          else
            new_node.merge!(service)
            service.nodes << node # this is odd, but we want the node pointer, not new_node pointer.
          end
        end
      end
      if node['tags']
        node['tags'].sort.each do |node_tag|
          tag = @tags[node_tag]
          if tag.nil?
            log0('Error in node "%s": the tag "%s" does not exist.' % [node['name'], node_tag])
          else
            new_node.merge!(tag)
            tag.nodes << node
          end
        end
      end
      new_node.merge!(node)
      node.replace(new_node)
    end

    def nodes_for_filter(filter)
      if node = self.nodes[filter]
        ConfigList.new(node)
      elsif service = self.services[filter]
        service.nodes
      elsif tag = self.tags[filter]
        tag.nodes
      end
    end

  end

end
