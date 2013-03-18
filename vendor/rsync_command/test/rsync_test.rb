require 'test/unit'
require File.expand_path('../../lib/rsync_command', __FILE__)

if RUBY_VERSION >= '1.9'
  SimpleOrderedHash = ::Hash
else
  class SimpleOrderedHash < Hash
    def each; self.keys.map(&:to_s).sort.each {|key| yield [key.to_sym, self[key.to_sym]]}; end
  end
end

class RsyncTest < Test::Unit::TestCase

  def test_build_simple_command
    command = rsync_command('bar', 'foo')
    assert_equal 'rsync -az bar foo', command
  end

  def test_allows_passing_delete
    command = rsync_command('bar', 'foo', :delete => true)
    assert_equal 'rsync -az --delete bar foo', command
  end

  def test_allows_specifying_an_exclude
    command = rsync_command('bar', 'foo', :excludes => '.git')
    assert_equal "rsync -az --exclude='.git' bar foo", command
  end

  def test_ssh_options_keys_only_lists_existing_files
    command = rsync_command('.', 'foo', :ssh => { :keys => [__FILE__, "#{__FILE__}dadijofs"] })
    assert_match /-i '#{__FILE__}'/, command
  end

  def test_ssh_options_ignores_keys_if_nil
    command = rsync_command('.', 'foo', :ssh => { :keys => nil })
    assert_equal 'rsync -az . foo', command
    command = rsync_command('bar', 'foo')
    assert_equal 'rsync -az bar foo', command
  end

  def test_ssh_options_config_adds_flag
    command = rsync_command('.', 'foo', :ssh => { :config => __FILE__ })
    assert_equal %Q[rsync -az -e "ssh -F '#{__FILE__}'" . foo], command
  end

  def test_ssh_options_port_adds_port
    command = rsync_command('.', 'foo', :ssh => { :port => '30022' })
    assert_equal %Q[rsync -az -e "ssh -p 30022" . foo], command
  end

  def test_ssh_options_ignores_config_if_nil_or_false
    command = rsync_command('.', 'foo', :ssh => { :config => nil })
    assert_equal 'rsync -az . foo', command
    command = rsync_command('.', 'foo', :ssh => { :config => false })
    assert_equal 'rsync -az . foo', command
  end

  def test_remote_address
    cmd = rsync_command('.', {:user => 'user', :host => 'box.local', :path => '/tmp'})
    assert_equal "rsync -az . user@box.local:/tmp", cmd
  end

  #def test_remote_address_drops_at_when_user_is_nil
  #  assert_equal 'box.local:/tmp', SupplyDrop::Rsync.remote_address(nil, 'box.local', '/tmp')
  #end

  protected

  def rsync_command(src, dest, options={})
    rsync = RsyncCommand.new(:flags => '-az')
    rsync.command(src, dest, options)
  end

end