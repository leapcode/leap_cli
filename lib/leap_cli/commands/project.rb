require 'fileutils'

module LeapCli; module Commands

  desc 'Initializes a new LEAP provider in the specified directory.'
  arg_name 'directory-path'
  skips_pre
  command :init do |c|
    c.flag 'name', :desc => "The name of the provider", :default_value => 'Example'
    c.flag 'domain', :desc => "The primary domain of the provider", :default_value => 'example.org'
    c.flag 'platform', :desc => "File path of the leap_platform directory", :default_value => '../leap_platform'
    c.action do |global_options, options, args|
      directory = args.first
      unless directory && directory.any?
        help! "Directory name is required."
      end
      directory = File.expand_path(directory)
      unless File.exists?(directory)
        bail! { log :missing, "directory #{directory}" }
      end
      create_initial_provider_files(directory, options)
    end
  end

  private

  DEFAULT_REPO = 'git://leap.se/leap_platform' # TODO: use https

  #
  # creates new provider directory
  #
  def create_initial_provider_files(directory, options)
    Path.set_provider_path(directory)
    Dir.chdir(directory) do
      assert_files_missing! 'provider.json', 'common.json', 'Leapfile', :base => directory

      platform_dir = File.expand_path(options[:platform])

      unless File.symlink?(platform_dir) || File.directory?(platform_dir)
        if agree("The platform directory \"#{options[:platform]}\" does not exist.\nDo you want me to create it by cloning from the\ngit repository #{DEFAULT_REPO}? ")
          assert_bin! 'git'
          ensure_dir platform_dir
          Dir.chdir(platform_dir) do
            log :cloning, "leap_platform into #{platform_dir}"
            pty_run "git clone --branch develop #{DEFAULT_REPO} ."
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

  def leapfile_content(options)
    %[@platform_directory_path = "#{options[:platform]}"
]
    # leap_version = "#{LeapCli::VERSION}"
    # platform_version = ""
  end

  GITIGNORE_CONTENT = <<EOS
test/Vagrantfile
test/.vagrant
test/openvpn
test/cert
EOS

  def provider_content(options)
  %[#
# General service provider configuration.
#
{
  "domain": "#{options[:domain]}",
  "name": {
    "en": "#{options[:name]}"
  },
  "description": {
    "en": "You really should change this text"
  },
  "languages": ["en"],
  "default_language": "en",
  "enrollment_policy": "open"
}
]
  end

  COMMON_CONTENT = <<EOS
#
# Options put here are inherited by all nodes.
#
{
}
EOS

end; end


