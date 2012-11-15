# run 'rake update-requirements' to generate this file.
module LeapCli
  REQUIREMENTS = [
    "provider.ca.name",
    "provider.ca.bit_size",
    "provider.ca.life_span",
    "provider.ca.server_certificates.bit_size",
    "provider.ca.server_certificates.life_span",
    "common.x509.use",
    "provider.vagrant.network"
  ]
end
