require File.dirname(__FILE__) + '/test_helper'

class TestMeme < MiniTest::Unit::TestCase

  def test_node_search
    nodes = manager.nodes['name' => 'vpn1']
    assert_equal 1, nodes.size
    assert_equal 'vpn1', nodes.values.first.name
  end

  def test_complex_node_search
    nodes = manager.nodes['dns.public' => true]
    expected = [{"domain_full"=>"ns1.rewire.co"}, {"domain_full"=>"ns2.rewire.co"}, {"domain_full"=>"vpn1.rewire.co"}, {"domain_full"=>"web1.rewire.co"}]
    assert_equal expected.size, nodes.size
    assert_equal expected, nodes.fields('domain.full')
  end



end
