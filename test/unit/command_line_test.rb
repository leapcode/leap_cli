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

end
