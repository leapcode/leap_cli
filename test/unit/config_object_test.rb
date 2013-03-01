require File.expand_path('../test_helper', __FILE__)

class ConfigObjectTest < MiniTest::Unit::TestCase

  def test_bracket_lookup
    domain = provider.domain
    vpn1 = manager.nodes['vpn1']
    assert_equal "vpn1.#{domain}", vpn1['domain.full']
  end

end
