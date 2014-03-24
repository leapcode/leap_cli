require 'fileutils'

module LeapCli; module Commands

  desc 'Creates a new provider instance in the specified directory, creating it if necessary.'
  arg_name 'DIRECTORY'
  skips_pre
  command :new do |c|
    c.flag 'name', :desc => "The name of the provider." #, :default_value => 'Example'
    c.flag 'domain', :desc => "The primary domain of the provider." #, :default_value => 'example.org'
    c.flag 'platform', :desc => "File path of the leap_platform directory." #, :default_value => '../leap_platform'
    c.flag 'contacts', :desc => "Default email address contacts." #, :default_value => 'root'

    c.action do |global, options, args|
      directory = File.expand_path(args.first)
      create_provider_directory(global, directory)
      options[:domain]   ||= ask_string("The primary domain of the provider: ") {|q| q.default = 'example.org'}
      options[:name]     ||= ask_string("The name of the provider: ") {|q| q.default = 'Example'}
      options[:platform] ||= ask_string("File path of the leap_platform directory: ") {|q| q.default = File.expand_path('../leap_platform', directory)}
      options[:platform] = "./" + options[:platform] unless options[:platform] =~ /^\//
      options[:contacts] ||= ask_string("Default email address contacts: ") {|q| q.default = 'root@' + options[:domain]}
      options[:platform] = relative_path(options[:platform])
      create_initial_provider_files(directory, global, options)
    end
  end

  private

  DEFAULT_REPO = 'https://leap.se/git/leap_platform.git'

  #
  # don't let the user specify any of the following: y, yes, n, no
  # they must actually input a real string
  #
  def ask_string(str, &block)
    while true
      value = ask(str, &block)
      if value =~ /^(y|yes|n|no)$/i
        say "`#{value}` is not a valid value. Try again"
      else
        return value
      end
    end
  end

  #
  # creates a new provider directory
  #
  def create_provider_directory(global, directory)
    unless directory && directory.any?
      help! "Directory name is required."
    end
    unless File.exists?(directory)
      if global[:yes] || agree("Create directory #{directory}? ")
        ensure_dir directory
      else
        bail! { log :missing, "directory #{directory}" }
      end
    end
    Path.set_provider_path(directory)
  end

  #
  # see provider with initial files
  #
  def create_initial_provider_files(directory, global, options)
    Dir.chdir(directory) do
      assert_files_missing! 'provider.json', 'common.json', 'Leapfile', :base => directory

      platform_dir = File.expand_path(options[:platform], "./")
      unless File.symlink?(platform_dir) || File.directory?(platform_dir)
        if global[:yes] || agree("The platform directory \"#{platform_dir}\" does not exist.\nDo you want me to create it by cloning from the\ngit repository #{DEFAULT_REPO}? ")
          assert_bin! 'git'
          ensure_dir platform_dir
          Dir.chdir(platform_dir) do
            log :cloning, "leap_platform into #{platform_dir}"
            pty_run "git clone --branch master #{DEFAULT_REPO} ."
            pty_run 'git submodule update --init'
          end
        else
          bail!
        end
      end
      write_file! '.gitignore', GITIGNORE_CONTENT
      write_file! 'provider.json', provider_content(options)
      write_file! 'common.json', COMMON_CONTENT
      write_file! 'Leapfile', leapfile_content(options)
      ["nodes", "services", "tags"].each do |dir|
        ensure_dir dir
      end
      log :completed, 'initialization'
    end
  end

  def relative_path(path)
    Pathname.new(File.expand_path(path)).relative_path_from(Pathname.new(Path.provider)).to_s
  end

  def leapfile_content(options)
    %[@platform_directory_path = "#{options[:platform]}"\n# see https://leap.se/en/docs/platform/config for more options]
  end

  GITIGNORE_CONTENT = <<EOS
test/Vagrantfile
test/.vagrant
test/openvpn
test/cert
EOS

  def provider_content(options)
  %[//
// General service provider configuration.
//
{
  "domain": "#{options[:domain]}",
  "name": {
    "en": "#{options[:name]}"
  },
  "description": {
    "en": "You really should change this text"
  },
  "contacts": {
    "default": "#{options[:contacts]}"
  },
  "languages": ["en"],
  "default_language": "en",
  "enrollment_policy": "open"
}
]
  end

  COMMON_CONTENT = <<EOS
//
// Options put here are inherited by all nodes.
//
{
}
EOS

end; end


