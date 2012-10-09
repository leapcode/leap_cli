require 'fileutils'

module LeapCli
  #
  # creates new provider directory
  #
  def self.init(directory)
    dirs = [directory]
    mkdirs(dirs, false, false)

    Dir.chdir(directory) do
      dirs = ["nodes", "services", "keys", "tags"]
      mkdirs(dirs, false, false)

      #puts "Creating .provider"
      #FileUtils.touch('.provider')

      mkfile("provider.json", PROVIDER_CONTENT)
      mkfile("common.json", COMMON_CONTENT)
    end
  end

  def self.mkfile(filename, content)
    puts "Creating #{filename}"
    File.open(filename, 'w') do |f|
      f.write content
    end
  end

  def self.mkdirs(dirs,force,dry_run)
    exists = false
    if !force
      dirs.each do |dir|
        if File.exist? dir
          raise "#{dir} exists; use --force to override"
          exists = true
        end
      end
    end
    if !exists
      dirs.each do |dir|
        puts "Creating #{dir}/"
        if dry_run
          puts "dry-run; #{dir} not created"
        else
          FileUtils.mkdir_p dir
        end
      end
    else
      puts "Exiting..."
      return false
    end
    true
  end

  PROVIDER_CONTENT = <<EOS
#
# Global provider definition file.
#
{
  "domain": "example.org"
}
EOS

  COMMON_CONTENT = <<EOS
#
# Options put here are inherited by all nodes.
#
{
  "domain": "example.org"
}
EOS

end
