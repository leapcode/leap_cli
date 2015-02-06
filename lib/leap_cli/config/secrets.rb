# encoding: utf-8
#
# A class for the secrets.json file
#

module LeapCli; module Config

  class Secrets < Object
    attr_reader :node_list

    def initialize(manager=nil)
      super(manager)
      @discovered_keys = {}
    end

    # we can't use fetch() or get(), since those already have special meanings
    def retrieve(key, environment=nil)
      self.fetch(environment||'default', {})[key.to_s]
    end

    def set(key, value, environment=nil)
      environment ||= 'default'
      key = key.to_s
      @discovered_keys[environment] ||= {}
      @discovered_keys[environment][key] = true
      self[environment] ||= {}
      self[environment][key] ||= value
    end

    #
    # if clean is true, then only secrets that have been discovered
    # during this run will be exported.
    #
    # if environment is also pinned, then we will clean those secrets
    # just for that environment.
    #
    # the clean argument should only be used when all nodes have
    # been processed, otherwise secrets that are actually in use will
    # get mistakenly removed.
    #
    def dump_json(clean=false)
      pinned_env = LeapCli.leapfile.environment
      if clean
        self.each_key do |environment|
          if pinned_env.nil? || pinned_env == environment
            self[environment].each_key do |key|
              unless @discovered_keys[environment] && @discovered_keys[environment][key]
                self[environment].delete(key)
              end
            end
            if self[environment].empty?
              self.delete(environment)
            end
          end
        end
      end
      super()
    end
  end

end; end
