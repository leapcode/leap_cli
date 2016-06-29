#
# The Leapfile is the bootstrap configuration file for a LEAP provider.
#
# It is akin to a Gemfile, Rakefile, or Capfile (e.g. it is a ruby file that gets eval'ed)
#
# Additional configuration options are defined in platform's leapfile_extensions.rb
#

module LeapCli
  def self.leapfile
    @leapfile ||= Leapfile.new
  end

  class Leapfile
    attr_reader :platform_directory_path
    attr_reader :provider_directory_path
    attr_reader :environment

    def initialize
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
        platform_class = "#{@platform_directory_path}/lib/leap/platform"
        platform_definition = "#{@platform_directory_path}/platform.rb"
        unless File.exist?(platform_definition)
          Util.bail! "ERROR: The file `#{platform_file}` does not exist. Please check the value of `@platform_directory_path` in `Leapfile` or `~/.leaprc`."
        end
        require platform_class
        require platform_definition
        begin
          Leap::Platform.validate!(LeapCli::VERSION, LeapCli::COMPATIBLE_PLATFORM_VERSION, self)
        rescue StandardError => exc
          Util.bail! exc.to_s
        end
        leapfile_extensions = "#{@platform_directory_path}/lib/leap_cli/leapfile_extensions.rb"
        if File.exist?(leapfile_extensions)
          require leapfile_extensions
        end

        #
        # validate
        #
        instance_variables.each do |var|
          var = var.to_s.sub('@', '')
          if !self.respond_to?(var)
            LeapCli.log :warning, "the variable `#{var}` is set in .leaprc or Leapfile, but it is not supported."
          end
        end
        @valid = validate
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
      if File.exist?(file_path)
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
      if File.exist? file
        LeapCli.log 2, :read, file
        instance_eval(File.read(file), file)
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

    # to be overridden
    def validate
      return true
    end

    def method_missing(method, *args)
      if method =~ /=$/
        self.instance_variable_set('@' + method.to_s.sub('=',''), args.first)
      else
        self.instance_variable_get('@' + method.to_s)
      end
    end

  end
end

