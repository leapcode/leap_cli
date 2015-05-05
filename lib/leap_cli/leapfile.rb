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
    attr_accessor :vagrant_network
    attr_accessor :environment

    def initialize
      @vagrant_network = '10.5.5.0/24'
    end

    #
    # The way the Leapfile handles pinning of environment (self.environment) is a little tricky.
    # If self.environment is nil, then there is no pin. If self.environment is 'default', then
    # there is a pin to the default environment. The problem is that an environment of nil
    # is used to indicate the default environment in node properties.
    #
    # This method returns the environment tag as needed when filtering nodes.
    #
    def environment_filter
      if self.environment == 'default'
        nil
      else
        self.environment
      end
    end

    def load(search_directory=nil)
      directory = File.expand_path(find_in_directory_tree('Leapfile', search_directory))
      if directory == '/'
        return nil
      else
        #
        # set up paths
        #
        @provider_directory_path = directory
        begin
          # load leaprc first, so that we can potentially access which environment is pinned in Leapfile
          # but also load leaprc last, so that it can override what is set in Leapfile.
          read_settings(leaprc_path)
        rescue StandardError
        end
        read_settings(directory + '/Leapfile')
        read_settings(leaprc_path)
        @platform_directory_path = File.expand_path(@platform_directory_path || '../leap_platform', @provider_directory_path)

        #
        # load the platform
        #
        platform_file = "#{@platform_directory_path}/platform.rb"
        unless File.exists?(platform_file)
          Util.bail! "ERROR: The file `#{platform_file}` does not exist. Please check the value of `@platform_directory_path` in `Leapfile` or `~/.leaprc`."
        end
        require "#{@platform_directory_path}/platform.rb"
        if !Leap::Platform.compatible_with_cli?(LeapCli::VERSION) ||
           !Leap::Platform.version_in_range?(LeapCli::COMPATIBLE_PLATFORM_VERSION)
          Util.bail! "This leap command (v#{LeapCli::VERSION}) " +
                     "is not compatible with the platform #{@platform_directory_path} (v#{Leap::Platform.version}).\n   " +
                     "You need either leap command #{Leap::Platform.compatible_cli.first} to #{Leap::Platform.compatible_cli.last} or " +
                     "platform version #{LeapCli::COMPATIBLE_PLATFORM_VERSION.first} to #{LeapCli::COMPATIBLE_PLATFORM_VERSION.last}"
        end
        unless @allow_production_deploy.nil?
          Util::log 0, :warning, "in Leapfile: @allow_production_deploy is no longer supported."
        end
        unless @platform_branch.nil?
          Util::log 0, :warning, "in Leapfile: @platform_branch is no longer supported."
        end
        @valid = true
        return @valid
      end
    end

    def set(property, value)
      edit_leaprc(property, value)
    end

    def unset(property)
      edit_leaprc(property)
    end

    def valid?
      !!@valid
    end

    private

    #
    # adds or removes a line to .leaprc for this particular provider directory.
    # if value is nil, the line is removed. if not nil, it is added or replaced.
    #
    def edit_leaprc(property, value=nil)
      file_path = leaprc_path
      lines = []
      if File.exists?(file_path)
        regexp = /self\.#{Regexp.escape(property)} = .*? if @provider_directory_path == '#{Regexp.escape(@provider_directory_path)}'/
        File.readlines(file_path).each do |line|
          unless line =~ regexp
            lines << line
          end
        end
      end
      unless value.nil?
        lines << "self.#{property} = #{value.inspect} if @provider_directory_path == '#{@provider_directory_path}'\n"
      end
      File.open(file_path, 'w') do |f|
        f.write(lines.join)
      end
    rescue Errno::EACCES, IOError => exc
      Util::bail! :error, "trying to save ~/.leaprc (#{exc})."
    end

    def leaprc_path
      File.join(ENV['HOME'], '.leaprc')
    end

    def read_settings(file)
      if File.exists? file
        Util::log 2, :read, file
        instance_eval(File.read(file), file)
        validate(file)
      end
    end

    def find_in_directory_tree(filename, directory_tree=nil)
      search_dir = directory_tree || Dir.pwd
      while search_dir != "/"
        Dir.foreach(search_dir) do |f|
          return search_dir if f == filename
        end
        search_dir = File.dirname(search_dir)
      end
      return search_dir
    end

    PRIVATE_IP_RANGES = /(^127\.0\.0\.1)|(^10\.)|(^172\.1[6-9]\.)|(^172\.2[0-9]\.)|(^172\.3[0-1]\.)|(^192\.168\.)/

    def validate(file)
      Util::assert! vagrant_network =~ PRIVATE_IP_RANGES do
        Util::log 0, :error, "in #{file}: vagrant_network is not a local private network"
      end
    end

  end
end

