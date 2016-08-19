About LEAP command line interface
===================================================

This gem installs an executable 'leap' that allows you to manage servers using the LEAP platform. You can read about the [platform on-line](https://leap.se/docs).

Installation
===================================================

Install prerequisites:

    sudo apt-get install git ruby ruby-dev rsync openssh-client openssl rake gcc make zlib1g-dev

NOTE: leap_cli requires ruby 1.9 or later.

Optionally install Vagrant in order to be able to test with local virtual machines (recommended):

    sudo apt-get install vagrant virtualbox zlib1g-dev

Install the `leap` command system-wide:

    sudo gem install leap_cli

Alternately, you can install just for your user:

    gem install --user-install leap_cli
    [ $(which ruby) ] && PATH="$PATH:$(ruby -e 'puts Gem.user_dir')/bin"

The `--user-install` option for `gem` will install gems to a location in your home directory (handy!) but this directory is not in your PATH (not handy!). Add the second line to your `.bashrc` file so that all your shells will have `leap` in PATH.

For other methods of installing `leap_cli`, see below.

Usage
===================================================

* Run `leap help` for a help with commands.
* Visit https://leap.se/docs/platform for tutorials and detailed documentation.

Development
===================================================

How to set up your environment for developing the ``leap`` command.

Prerequisites
---------------------------------------------------

Debian & Ubuntu

    sudo apt-get install git ruby ruby-dev rake bundler

Install from git
---------------------------------------------------

Download the source:

    cd leap_cli

Installing from the source
---------------------------------------------------

Build the gem:

    git clone https://leap.se/git/leap_cli.git
    cd leap_cli
    rake build

Install as root user:

    sudo rake install

Alternately, install as unprivileged user:

    rake install
    PATH="$PATH:$(ruby -e 'puts Gem.user_dir')/bin"

Running directly from the source directory
---------------------------------------------------

To run the ``leap`` command directly from the source tree, you need to install
the required gems using ``bundle`` and symlink ``bin/leap`` into your path:

    git clone https://leap.se/git/leap_cli.git
    cd leap_cli
    bundle                        # install required gems
    ln -s `pwd`/bin/leap ~/bin    # link executable somewhere in your bin path
    which leap                    # make sure you will run leap_cli/bin/leap
    leap help

If you get an error, make sure to check ``which leap``. Some versions of ``bundle`` will
incorrectly install a broken ``leap`` command in the gem bin directory when you do ``bundle``.

Why not use ``bundle exec leap`` to run the command? This works, so long as your current
working directory is under leap_cli. Because the point is to be able to run ``leap`` in
other places, it is easier to create the symlink. If you run ``leap`` directly, and not via
the command launcher that rubygems installs, leap will run in a mode that simulates
``bundle exec leap`` (i.e. only gems included in Gemfile are allowed to be loaded).
