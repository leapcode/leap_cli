module LeapCli
  unless defined?(LeapCli::VERSION)
    VERSION = '0.1.4'
    SUMMARY = 'Command line interface to the LEAP platform'
    DESCRIPTION = 'The command "leap" can be used to manage a bevy of servers running the LEAP platform from the comfort of your own home.'
    REQUIRE_PATHS = ['lib', 'vendor/supply_drop/lib', 'vendor/certificate_authority/lib']
  end
end
