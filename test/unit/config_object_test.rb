require_relative 'test_helper'

class ConfigObjectTest < Minitest::Test

  def test_bracket_lookup
    domain = provider.domain
    vpn1 = manager.nodes['vpn1']
    assert_equal "vpn1.#{domain}", vpn1['domain.full']
  end

end
