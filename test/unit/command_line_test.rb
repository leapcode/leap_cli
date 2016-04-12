require File.expand_path('../test_helper', __FILE__)

class CommandLineTest < Minitest::Test

  def test_help
    with_multiple_rubies do
      output = leap_bin('help')
      assert_equal 0, $?, "help should exit 0 -- #{output}"
    end
  end

  def test_list
    with_multiple_rubies do
      output = leap_bin('list')
      assert_equal 0, $?, "list should exit 0"
      assert output =~ /ns1   dns/m
    end
  end

  def test_add_node
    output = leap_bin("node add banana tags:production services:openvpn ip_address:1.1.1.1")
    cleanup_files('nodes/banana.json', 'files/nodes/banana')
    assert_match /created nodes\/banana\.json/, output
    assert_match /created files\/nodes\//, output
  end

end
