module LeapCli
  unless defined?(LeapCli::VERSION)
    VERSION = '1.9'
    COMPATIBLE_PLATFORM_VERSION = '0.9'..'0.99'
    SUMMARY = 'Command line interface to the LEAP platform'
    DESCRIPTION = 'The command "leap" can be used to manage a bevy of servers running the LEAP platform from the comfort of your own home.'
    LOAD_PATHS = ['lib',
      'vendor/certificate_authority/lib',
      'vendor/rsync_command/lib',
      'vendor/base32/lib',
      'vendor/acme-client/lib'
    ]
  end
end
