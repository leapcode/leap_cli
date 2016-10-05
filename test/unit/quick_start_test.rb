require_relative 'test_helper'

#
# Runs all the commands in https://leap.se/quick-start
#

Minitest.after_run {
  FileUtils.rm_r(QuickStartTest::TMP_PROVIDER)
}

class QuickStartTest < Minitest::Test

  # very reasonable to have ordered tests in this case, actually
  i_suck_and_my_tests_are_order_dependent!

  TMP_PROVIDER = Dir.mktmpdir("test_leap_provider_")

  #
  # use minimal bit sizes for our test.
  #
  PROVIDER_JSON = <<HERE
{
  "domain": "example.org",
  "name": {
    "en": "Example"
  },
  "description": {
    "en": "Example"
  },
  "languages": ["en"],
  "default_language": "en",
  "enrollment_policy": "open",
  "contacts": {
    "default": "root@localhost"
  },
  "ca": {
    "bit_size": 1024,
    "client_certificates": {
      "bit_size": 1024,
      "digest": "SHA1",
      "life_span": "100 years"
    },
    "life_span": "100 years",
    "server_certificates": {
      "bit_size": 1024,
      "digest": "SHA1",
      "life_span": "100 years"
    }
  }
}
HERE

  def provider_path
    TMP_PROVIDER
  end

  def test_01_new
    output = leap_bin! "new --contacts me@example.org --domain example.org --name Example --platform='#{platform_path}' ."
    assert_file "Leapfile"
    assert_file "provider.json"
    assert_dir "nodes"
    File.write(File.join(provider_path, 'provider.json'), PROVIDER_JSON)
  end

  def test_02_ca
    leap_bin! "cert ca"
    assert_dir "files/ca"
    assert_file "files/ca/ca.crt"
    assert_file "files/ca/ca.key"
  end

  def test_03_csr
    leap_bin! "cert csr"
    assert_file "files/cert/example.org.csr"
    assert_file "files/cert/example.org.crt"
    assert_file "files/cert/example.org.key"
  end

  def test_04_nodes
    leap_bin! "node add wildebeest ip_address:1.1.1.2 services:webapp,couchdb"
    leap_bin! "node add hippo ip_address:1.1.1.3 services:static"
    assert_file "nodes/wildebeest.json"
    assert_dir "files/nodes/wildebeest"
    assert_file "files/nodes/wildebeest/wildebeest.crt"
    assert_file "files/nodes/wildebeest/wildebeest.key"
  end

  def test_05_compile
    user_dir = File.join(provider_path, 'users', 'dummy')
    user_key = File.join(user_dir, 'dummy_ssh.pub')
    FileUtils.mkdir_p(user_dir)
    File.write(user_key, 'ssh-rsa dummydummydummy')

    leap_bin! "compile"
    assert_file "hiera/wildebeest.yaml"
    assert_file "hiera/hippo.yaml"
  end

  def test_06_rename
    leap_bin! "node mv hippo hippopotamus"
    assert_file "nodes/hippopotamus.json"
    assert_dir "files/nodes/hippopotamus"
    assert_file "files/nodes/hippopotamus/hippopotamus.key"
  end

  def test_07_rm
    leap_bin! "node rm hippopotamus"
    assert_file_missing "nodes/hippopotamus.json"
    assert_file_missing "files/nodes/hippopotamus/hippopotamus.key"
  end

  def assert_file(path)
    assert File.exist?(File.join(provider_path, path)), "The file `#{path}` should exist in #{provider_path}. Actual: \n#{provider_files}"
  end

  def assert_file_missing(path)
    assert !File.exist?(File.join(provider_path, path)), "The file `#{path}` should NOT exist in #{provider_path}."
  end

  def assert_dir(path)
    assert Dir.exist?(File.join(provider_path, path)), "The directory `#{path}` should exist in #{provider_path}. Actual: \n#{provider_files}"
  end

  def provider_files
    `cd #{provider_path} && find .`
  end
end
