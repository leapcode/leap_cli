require File.expand_path('test_helper', File.dirname(__FILE__))

class TestMeme < MiniTest::Unit::TestCase

  def test_bracket_lookup
    vpn1 = manager.nodes['vpn1']
    assert_equal 'vpn1.rewire.co', vpn1['domain.full']
  end

end
