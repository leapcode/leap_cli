require "rubygems"
require "pty"
require "fileutils"
require "rake/testtask"

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
$base_dir  = File.dirname(__FILE__)
$spec      = eval(File.read(File.join($base_dir, $spec_path)))
$gem_path  = File.join($base_dir, 'pkg', "#{$spec.name}-#{$spec.version}.gem")
$lib_dir   = "#{$base_dir}/lib"
$LOAD_PATH.unshift $lib_dir

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
  puts "#{$spec.name} #{$spec.version} built to pkg/#{file_name}"
end

desc "Install #{$spec.name}-#{$spec.version}.gem into either system-wide or user gems"
task 'install' do
  if !File.exists?($gem_path)
    puts("Could not file #{$gem_path}. Try running 'rake build'")
  else
    options = '--verbose --conservative --no-rdoc --no-ri'
    if ENV["USER"] == "root"
      run "gem install #{options} '#{$gem_path}'"
    else
      home_gem_path = Gem.path.grep(/home/).first
      puts "You are installing as an unprivileged user, which will result in the installation being placed in '#{home_gem_path}'."
      print "Do you want to continue installing to #{home_gem_path}? [y/N] "
      input = STDIN.readline
      if input =~ /[yY]/
        run "gem install #{$gem_path} #{options} --install-dir '#{home_gem_path}' "
      else
        puts "bailing out."
      end
    end
  end
end

desc "Uninstall #{$spec.name}-#{$spec.version}.gem from either system-wide or user gems"
task 'uninstall' do
  if ENV["USER"] == "root"
    puts "Removing #{$spec.name}-#{$spec.version}.gem from system-wide gems"
    run "gem uninstall '#{$spec.name}' --version #{$spec.version} --verbose -x -I"
  else
    puts "Removing #{$spec.name}-#{$spec.version}.gem from user's gems"
    run "gem uninstall '#{$spec.name}' --version #{$spec.version} --verbose --user-install -x -I"
  end
end

##
## TESTING
##

Rake::TestTask.new do |t|
  t.pattern = "test/unit/*_test.rb"
end
task :default => :test

##
## CODE GENERATION
##

desc "Updates the list of required configuration options for this version of LEAP CLI"
task 'update-requirements' do
  Dir.chdir($base_dir) do
    required_configs = `find -name '*.rb' | xargs grep -R 'assert_config!'`.split("\n").collect{|line|
      if line =~ /def/ || line =~ /pre\.rb/
        nil
      else
        line.sub(/.*assert_config! ["'](.*?)["'].*/,'"\1"')
      end
    }.compact
    File.open("#{$base_dir}/lib/leap_cli/requirements.rb", 'w') do |f|
      f.puts "# run 'rake update-requirements' to generate this file."
      f.puts "module LeapCli"
      f.puts "  REQUIREMENTS = ["
      f.puts "    " + required_configs.join(",\n    ")
      f.puts "  ]"
      f.puts "end"
    end
    puts "updated #{$base_dir}/lib/leap_cli/requirements.rb"
    #puts `cat '#{$base_dir}/lib/leap_cli/requirements.rb'`
  end
end

##
## DOCUMENTATION
##

# require 'rdoc/task'

# Rake::RDocTask.new do |rd|
#   rd.main = "README.rdoc"
#   rd.rdoc_files.include("README.rdoc","lib/**/*.rb","bin/**/*")
#   rd.title = 'Your application title'
# end

desc "Generate documentation"
task 'doc' do
  require 'leap_cli'
  require 'leap_cli/app'

  class DocMaker < GLI::Command
    def initialize(app)
      @app = app
      @listener = GLI::Commands::RdocDocumentListener.new([],[],[])
    end

    def create
      @listener.beginning
      @listener.program_desc(@app.program_desc) unless @app.program_desc.nil?
      @listener.program_long_desc(@app.program_long_desc) unless @app.program_long_desc.nil?
      @listener.version(@app.version_string)
      if any_options?(@app)
        @listener.options
      end
      document_flags_and_switches(@listener, @app.flags.values.sort(&by_name), @app.switches.values.sort(&by_name))
      if any_options?(@app)
        @listener.end_options
      end
      @listener.commands
      document_commands(@listener, @app)
      @listener.end_commands
      @listener.ending
    end

    private

    def document_commands(document_listener,context)
      context.commands.values.reject {|_| _.nodoc }.sort(&by_name).each do |command|
        call_command_method_being_backwards_compatible(document_listener,command)
        document_listener.options if any_options?(command)
        document_flags_and_switches(document_listener,command_flags(command),command_switches(command))
        document_listener.end_options if any_options?(command)
        document_listener.commands if any_commands?(command)
        document_commands(document_listener,command)
        document_listener.end_commands if any_commands?(command)
        document_listener.end_command(command.name)
      end
      document_listener.default_command(context.get_default_command)
    end

    def call_command_method_being_backwards_compatible(document_listener,command)
      command_args = [command.name,
                      Array(command.aliases),
                      command.description,
                      command.long_description,
                      command.arguments_description]
      if document_listener.method(:command).arity == 6
        command_args << command.arguments_options
      end
      document_listener.command(*command_args)
    end

    def by_name
      lambda { |a,b| a.name.to_s <=> b.name.to_s }
    end

    def command_flags(command)
      command.topmost_ancestor.flags.values.select { |flag| flag.associated_command == command }.sort(&by_name)
    end

    def command_switches(command)
      command.topmost_ancestor.switches.values.select { |switch| switch.associated_command == command }.sort(&by_name)
    end

    def document_flags_and_switches(document_listener,flags,switches)
      flags.each do |flag|
        document_listener.flag(flag.name,
                               Array(flag.aliases),
                               flag.description,
                               flag.long_description,
                               flag.safe_default_value,
                               flag.argument_name,
                               flag.must_match,
                               flag.type)
      end
      switches.each do |switch|
        document_listener.switch(switch.name,
                                 Array(switch.aliases),
                                 switch.description,
                                 switch.long_description,
                                 switch.negatable)
      end
    end

    def any_options?(context)
      options = if context.kind_of?(GLI::Command)
                  command_flags(context) + command_switches(context)
                else
                  context.flags.values + context.switches.values
                end
      !options.empty?
    end

    def any_commands?(command)
      !command.commands.empty?
    end
  end

  puts DocMaker.new(LeapCli::Commands).create
end
