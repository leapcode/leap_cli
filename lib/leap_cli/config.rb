module LeapCli
  #
  # This class represents the configuration for a single node, service, or tag.
  #
  class Config < Hash

    def initialize(config_type, manager)
      @manager = manager
      @type = config_type
    end

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
          value = eval($1)
          self[key] = value
        end
        value
      end
    end

    #
    # make the type appear to be a normal Hash in yaml.
    #
    def to_yaml_type
     "!map"
    end

    #
    # just like Hash#to_yaml, but sorted
    #
    def to_yaml(opts = {})
      YAML::quick_emit(self, opts) do |out|
        out.map(taguri, to_yaml_style) do |map|
          keys.sort.each do |k|
            v = self.fetch(k)
            map.add(k, v)
          end
        end
      end
    end

    #
    # make obj['name'] available as obj.name
    #
    def method_missing(method, *args, &block)
      if has_key?(method.to_s)
        self[method.to_s]
      else
        super
      end
    end

    #
    # convert self into a plain hash, but only include the specified keys
    #
    def to_h(*keys)
      keys.map(&:to_s).inject({}) do |hsh, key|
        if has_key?(key)
          hsh[key] = self[key]
        end
        hsh
      end
    end

    def nodes
      if @type == :node
        @manager.nodes
      else
        @nodes ||= ConfigList.new
      end
    end

    def services
      if @type == :node
        self['services'] || []
      else
        @manager.services
      end
    end

    def tags
      if @type == :node
        self['tags'] || []
      else
        @manager.tags
      end
    end

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