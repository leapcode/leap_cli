
#
# check to make sure we can find the root directory of the platform
#
module LeapCli; module Commands

  desc 'Verbosity level 0..5'
  arg_name 'LEVEL'
  default_value '1'
  flag [:v, :verbose]

  desc 'Override default log file.'
  arg_name 'FILE'
  default_value nil
  flag :log

  desc 'Display version number and exit.'
  switch :version, :negatable => false

  desc 'Skip prompts and assume "yes".'
  switch :yes, :negatable => false

  desc 'Like --yes, but also skip prompts that are potentially dangerous to skip.'
  switch :force, :negatable => false

  desc 'Print full stack trace for exceptions and load `debugger` gem if installed.'
  switch [:d, :debug], :negatable => false

  desc 'Disable colors in output.'
  default_value true
  switch 'color', :negatable => true

  pre do |global,command,options,args|
    Bootstrap.setup_global_options(self, global)
    true
  end

end; end
