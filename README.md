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

Run `leap help` for a usage instructions.

Here is an example usage:

    leap new-provider provider
    cd provider
    edit configuration files (see below)
    leap compile

Directories and Files
=================================

The general structure of leap project looks like this:

    my_leap_project/                 # your project directory
      leap_platform/                 # a clone of the leap_platform puppet recipes
      provider/                      # your provider-specific configurations

The "leap" command should be run from within the "provider" directory.

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

How to set up your environment for developing the ``leap`` command.

Prerequisites
---------------------------------

Debian Squeeze

    sudo apt-get install git ruby ruby-dev rubygems
    sudo gem install bundler rake
    export PATH=$PATH:/var/lib/gems/1.8/bin

Debian Wheezy

    sudo apt-get install git ruby ruby-dev
    sudo gem install bundler

Ubuntu Quantal

    sudo apt-get install git ruby ruby-dev
    sudo gem install bundler

Install from git
---------------------------------

Install requirements

    git clone git://leap.se/leap_cli      # clone leap_cli code
    cd leap_cli
    bundle                                # install required gems

Symlink bin/leap into your path:

    cd leap_cli
    ln -s `pwd`/bin/leap /usr/local/bin   # link executable somewhere in your bin path
    which leap                            # make sure you will run leap_cli/bin/leap,
                                          # and not /var/lib/gems/1.x/bin/leap
    leap help

If you get an error, make sure to check ``which leap``. Some versions of ``bundle`` will
incorrectly install a broken ``leap`` command in the gem bin directory when you do ``bundle``.

Why not use ``bundle exec leap`` to run the command? This works, so long as your current
working directory is under leap_cli. Because the point is to be able to run ``leap`` in
other places, it is easier to create the symlink. If you run ``leap`` directly, and not via
the command launcher that rubygems installs, leap will run in a mode that simulates
``bundle exec leap`` (i.e. only gems included in Gemfile are allow to be loaded).
