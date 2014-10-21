module LeapCli

  PUPPET_DESTINATION = '/srv/leap'
  CUSTOM_PUPPET_DESTINATION = '/srv/leap/custom-puppet'
  CUSTOM_PUPPET_SOURCE = '/files/custom-puppet/'
  CUSTOM_PUPPET_SITE = "#{CUSTOM_PUPPET_SOURCE}/manifests/site.pp"
  CUSTOM_PUPPET_MODULES = "#{CUSTOM_PUPPET_SOURCE}/modules"
  INITIALIZED_FILE = "#{PUPPET_DESTINATION}/initialized"
  DEFAULT_TAGS = ['leap_base','leap_service']

end
