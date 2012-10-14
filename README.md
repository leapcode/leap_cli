About LEAP command line interface
=================================

This gem installs an executable 'leap' that allows you to manage servers using the leap platform.

Installation
=================================

To install the gem:

    gem install leap_cli

To run from a clone of the git repo, see "Development", below.

Usage
=================================

This tool is incomplete, so most commands don't yet work.

Run `leap help` for a usage instructions.

Here is an example usage:

    leap init provider
    cd provider
    edit configuration files (see below)
    leap compile

Directories and Files
=================================

The general structure of leap project looks like this:

    my_leap_project/                 # the 'root' directory
      leap_platform/                 # a clone of the leap_platform puppet recipes
      provider/                      # your provider-specific configurations

The "leap" command should be run from within the "provider" directory.

You can name these directories whatever you like. The leap command will walk up the directory tree until it finds a directory that looks like a 'root' directory.

Within the "provider" directory:

    nodes/               # one configuration file per node (i.e. server)
    services/            # nodes inherit from these files if specified in node config.
    tags/                # nodes inherit from these files if specified in node config.
    files/               # text and binary files needed for services and nodes, including keypairs
    users/               # crypto key material for sysadmins
    common.yaml          # all nodes inherit these options
    provider.yaml        # global service provider definition

Configuration Files
=================================

All configuration files are in JSON format. For example

    {
      "key1": "value1",
      "key2": "value2"
    }

Keys should match /[a-z0-9_]/

Unlike traditional JSON, comments are allowed. If the first non-whitespace character is '#' the line is treated as a comment.

    # this is a comment
    {
      # this is a comment
      "key": "value"  # this is an error
    }

Options in the configuration files might be nested. For example:

    {
      "openvpn": {
        "ip_address": "1.1.1.1"
      }
    }

If the value string is prefixed with an '=' character, the value is evaluated as ruby. For example

    {
      "domain": {
        "public": "domain.org"
      }
      "api_domain": "= 'api.' + domain.public"
    }

In this case, "api_domain" will be set to "api.domain.org".

The following methods are available to the evaluated ruby:

* nodes -- A list of all nodes. This list can be filtered.

* global.services -- A list of all services.

* global.tags -- A list of all tags.

* file(file_path) -- Inserts the full contents of the file. If the file is an erb
  template, it is rendered. The file is searched for by first checking platform
  and then provider/files,

* variable -- Any variable inherited by a particular node is available
  by just referencing it using either hash notation or object notation
  (i.e. self['domain']['public'] or domain.public). Circular
  references are not allowed, but otherwise it is ok to nest
  evaluated values in other evaluated values.


Node Configuration
=================================

The name of the file will be the hostname of the node.

An example configuration "nodes/dns-europe.json"

    {
       "services": "dns",
       "tags": ["production", "europe"],
       "ip_address": "1.1.1.1"
    }

This node will have hostname "dns-europe" and it will inherit from the following files (in this order):

    common.json
    services/dns.json
    tags/europe.json
    tags/production.json

Development
=================================

prerequisites:

* rubygems (``apt-get install rubygems``)
* bundler  (``gem install bundler``)

Install command line ``leap``:

    git clone git://leap.se/leap_cli   # clone leap cli code
    cd leap_cli
    bundle                             # install required gems
    ln -s `pwd`/bin/leap ~/bin         # link executable somewhere in your bin path

You can experiment using the example provider in the test directory

    cd test/provider
    leap

Alternately, you can create your own provider for testing:

    mkdir ~/dev/example.org
    cd ~/dev/example.org
    git clone git://leap.se/leap_platform
    leap init provider
    cd provider
    leap

