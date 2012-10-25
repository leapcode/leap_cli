require "rubygems"
require "highline/import"
require "pty"
require "fileutils"

##
## HELPER
##

def run(cmd)
  PTY.spawn(cmd) do |output, input, pid|
    begin
      while line = output.gets do
        puts line
      end
    rescue Errno::EIO
    end
  end
rescue PTY::ChildExited
end

##
## GEM BUILDING AND INSTALLING
##

$spec_path = 'leap_cli.gemspec'
$spec      = eval(File.read($spec_path))
$base_dir  = File.dirname(__FILE__)
$gem_path  = File.join($base_dir, 'pkg', "#{$spec.name}-#{$spec.version}.gem")

def built_gem_path
  Dir[File.join($base_dir, "#{$spec.name}-*.gem")].sort_by{|f| File.mtime(f)}.last
end

desc "Build #{$spec.name}-#{$spec.version}.gem into the pkg directory"
task 'build' do
  FileUtils.mkdir_p(File.join($base_dir, 'pkg'))
  FileUtils.rm($gem_path) if File.exists?($gem_path)
  run "gem build -V '#{$spec_path}'"
  file_name = File.basename(built_gem_path)
  FileUtils.mv(built_gem_path, 'pkg')
  say "#{$spec.name} #{$spec.version} built to pkg/#{file_name}"
end

desc "Build and install #{$spec.name}-#{$spec.version}.gem into either system-wide or user gems"
task 'install' do
  if !File.exists?($gem_path)
    say("Could not file #{$gem_path}. Try running 'rake build'")
  else
    if ENV["USER"] == "root"
      run "gem install '#{$gem_path}'"
    else
      say("A system-wide install requires that you run 'rake install' as root, which you are not.")
      if agree("Do you want to continue installing to #{Gem.path.grep /home/}? ")
        run "gem install '#{$gem_path}' --user-install"
      end
    end
  end
end

##
## TESTING
##

# task :default => [:test,:features]

##
## DOCUMENTATION
##

# require 'rdoc/task'

# Rake::RDocTask.new do |rd|
#   rd.main = "README.rdoc"
#   rd.rdoc_files.include("README.rdoc","lib/**/*.rb","bin/**/*")
#   rd.title = 'Your application title'
# end
