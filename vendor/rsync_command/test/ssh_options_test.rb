require 'test/unit'
require File.expand_path('../../lib/rsync_command', __FILE__)

class SshOptionsTest < Test::Unit::TestCase

  def test_simple_ssh_options
    options = ssh_options(Hash[
      :bind_address, '0.0.0.0',
      :compression, true,
      :compression_level, 1,
      :config, '/etc/ssh/ssh_config',
      :global_known_hosts_file, '/etc/ssh/known_hosts',
      :host_name, 'myhost',
      :keys_only, false,
      :paranoid, true,
      :port, 2222,
      :timeout, 10000,
      :user, 'root',
      :user_known_hosts_file, '~/.ssh/known_hosts'
    ])
    assert_match /-o BindAddress='0.0.0.0'/, options
    assert_match /-o Compression='yes'/, options
    assert_match %r{-o CompressionLevel='1' -F '/etc/ssh/ssh_config'}, options
    assert_match %r{-o GlobalKnownHostsFile='/etc/ssh/known_hosts'}, options
    assert_match /-o HostName='myhost'/, options
    assert_match /-o StrictHostKeyChecking='yes' -p 2222/, options
    assert_match /-o ConnectTimeout='10000' -l root/, options
    assert_match %r{-o UserKnownHostsFile='~/.ssh/known_hosts'}, options
  end

  def test_complex_ssh_options
    options = ssh_options(Hash[
      :auth_methods, 'publickey',
      :encryption, ['aes256-cbc', 'aes192-cbc'],
      :hmac, 'hmac-sha2-256',
      :host_key, 'ecdsa-sha2-nistp256-cert-v01@openssh.com',
      :rekey_limit, 2*1024*1024,
      :verbose, :debug,
      :user_known_hosts_file, ['~/.ssh/known_hosts', '~/.ssh/production_known_hosts']
    ])
    assert_match /PasswordAuthentication='no'/, options
    assert_match /PubkeyAuthentication='yes'/, options
    assert_match /HostbasedAuthentication='no'/, options
    assert_match /-o PasswordAuthentication='no'/, options
    assert_match /-o PubkeyAuthentication='yes'/, options
    assert_match /-o HostbasedAuthentication='no'/, options
    assert_match /-o Ciphers='aes256-cbc,aes192-cbc'/, options
    assert_match /-o MACs='hmac-sha2-256'/, options
    assert_match /-o HostKeyAlgorithms='ecdsa-sha2-nistp256-cert-v01@openssh.com'/, options
    assert_match /-o RekeyLimit='2M'/, options
    assert_match %r{-o UserKnownHostsFile='~/.ssh/known_hosts'}, options
    assert_match %r{-o UserKnownHostsFile='~/.ssh/production_known_hosts'}, options
    assert_match /-o LogLevel='DEBUG'/, options
  end

  protected

  def ssh_options(options)
    RsyncCommand::SshOptions.new(options).to_flags
  end
end
