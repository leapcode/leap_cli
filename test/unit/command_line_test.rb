require File.expand_path('test_helper', File.dirname(__FILE__))

class CommandLineTest < MiniTest::Unit::TestCase

  def test_help
    with_multiple_rubies do
      output = leap_bin('help')
      assert_equal 0, $?, "help should exit 0 -- #{output}"
    end
  end

end
