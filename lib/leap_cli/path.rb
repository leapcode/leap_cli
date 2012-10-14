require 'fileutils'

module LeapCli
  module Path

    def self.root
      @root ||= File.expand_path("#{provider}/..")
    end

    def self.platform
      @platform ||= File.expand_path("#{root}/leap_platform")
    end

    def self.provider
      @provider ||= if @root
        File.expand_path("#{root}/provider")
      else
        find_in_directory_tree('provider.json')
      end
    end

    def self.hiera
      @hiera ||= "#{provider}/hiera"
    end

    def self.files
      @files ||= "#{provider}/files"
    end

    def self.ok?
      provider != '/'
    end

    def self.set_root(root_path)
      @root = File.expand_path(root_path)
      raise "No such directory '#{@root}'" unless File.directory?(@root)
    end

    def self.find_file(name, filename)
      path = [Path.files, filename].join('/')
      return path if File.exists?(path)
      path = [Path.files, name, filename].join('/')
      return path if File.exists?(path)
      path = [Path.files, 'nodes', name, filename].join('/')
      return path if File.exists?(path)
      path = [Path.files, 'services', name, filename].join('/')
      return path if File.exists?(path)
      path = [Path.files, 'tags', name, filename].join('/')
      return path if File.exists?(path)

      # give up
      return nil
    end

    private

    def self.find_in_directory_tree(filename)
      search_dir = Dir.pwd
      while search_dir != "/"
        Dir.foreach(search_dir) do |f|
          return search_dir if f == filename
        end
        search_dir = File.dirname(search_dir)
      end
      return search_dir
    end

  end
end
