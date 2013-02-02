#
# The Leapfile is the bootstrap configuration file for a LEAP provider.
#
# It is akin to a Gemfile, Rakefile, or Capfile (e.g. it is a ruby file that gets eval'ed)
#

module LeapCli
  def self.leapfile
    @leapfile ||= Leapfile.new
  end

  class Leapfile
    attr_accessor :platform_directory_path
    attr_accessor :provider_directory_path
    attr_accessor :custom_vagrant_vm_line
    attr_accessor :leap_version
    attr_accessor :log

    def load
      directory = File.expand_path(find_in_directory_tree('Leapfile'))
      if directory == '/'
        return nil
      else
        self.provider_directory_path = directory
        leapfile = directory + '/Leapfile'
        instance_eval(File.read(leapfile), leapfile)
        self.platform_directory_path = File.expand_path(self.platform_directory_path || '../leap_platform', self.provider_directory_path)
        return true
      end
    end

    private

    def find_in_directory_tree(filename)
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

