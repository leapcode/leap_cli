About LEAP command line interface
===================================================

This gem installs an executable 'leap' that allows you to manage servers using the LEAP platform. You can read about the [platform on-line](https://leap.se).

Installation
===================================================

Install prerequisites:

    sudo apt-get install git ruby ruby-dev rsync openssh-client openssl rake

Optionally install Vagrant in order to be able to test with local virtual machines (recommended):

    sudo apt-get install vagrant virtualbox

NOTE: leap_cli should work with ruby1.8, but has only been tested using ruby1.9.

Install the `leap` command:

    sudo gem install leap_cli

Alternately, you can install `leap` from source:

    sudo apt-get install rake
    git clone git://leap.se/leap_cli.git
    cd leap_cli
    rake build

Install as root user (recommended):

    sudo rake install

Install as unprivileged user:

    rake install
    # watch out for the directory leap is installed to, then i.e.
    sudo ln -s ~/.gem/ruby/1.9.1/bin/leap /usr/local/bin/leap

With both methods, you can use now /usr/local/bin/leap, which in most cases will be in your $PATH.

To run directly from a clone of the git repo, see "Development", below.

Usage
===================================================

* Run `leap help` for a help with commands.
* Visit https://leap.se/docs/platform for tutorials and detailed documentation.

Development
===================================================

How to set up your environment for developing the ``leap`` command.

Prerequisites
---------------------------------------------------

Debian Squeeze

    sudo apt-get install git ruby ruby-dev rubygems
    sudo gem install bundler rake
    export PATH=$PATH:/var/lib/gems/1.8/bin

Debian Wheezy

    sudo apt-get install git ruby ruby-dev bundler

Ubuntu

    sudo apt-get install git ruby ruby-dev
    sudo gem install bundler

Install from git
---------------------------------------------------

Download the source:

    git clone git://leap.se/leap_cli
    cd leap_cli

Running from the source directory
---------------------------------------------------

To run the ``leap`` command directly from the source tree, you need to install
the required gems using ``bundle`` and symlink ``bin/leap`` into your path:

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

Future development
----------------------------------------------------

(1) remove supply_drop - our use of supply drop no longer makes sense, as our needs diverge and we have more and more patches against upstream. the supply drop code we use should be cherry picked and brought into leap_cli.

  (a) create a separate rsync library independent of capistrano or supply_drop.
  (b) do our own rsync for the puppet manifests (make sure to include --copy-links)
  (c) do our own puppet apply, with capture of exit status.

(2) remove capistrano. we don't need it, and it makes it awkward to do what we want (exit codes, different options for different hosts). either use another shell lib, or roll our own. maybe something like 'remotedly(hosts) do |host|....'
