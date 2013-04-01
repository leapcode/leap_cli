module LeapCli
  unless defined?(LeapCli::VERSION)
    VERSION = '0.2.0'
    SUMMARY = 'Command line interface to the LEAP platform'
    DESCRIPTION = 'The command "leap" can be used to manage a bevy of servers running the LEAP platform from the comfort of your own home.'
    LOAD_PATHS = ['lib', 'vendor/certificate_authority/lib', 'vendor/rsync_command/lib']
  end
end
