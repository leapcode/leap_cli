Version 1.5.6

- Added try{} macro function that quietly swallows exceptions.
- Added ability to scope tags by environment.
- Added rand_range and base32_secret macros.
- Many ssh fixes
- Made --no-color work better
- Prevent `apt-get upgrade` when update fails.
- Always compile all hiera .yaml files.
- Fixs ntpd fixes

Version 1.5.3

- Better utf8 support
- Prevent invalid host names
- Allow json keys with periods in them
- Better `leap new`

Version 1.5.0

- Added ability to scope provider.json by environment
 
Version 1.2.5

- Added initial support for remote tests.
- Will now bail if /etc/leap/no-deploy is present on a node.
