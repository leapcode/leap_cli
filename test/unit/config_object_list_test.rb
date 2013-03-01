require File.expand_path('../test_helper', __FILE__)

class ConfigObjectListTest < MiniTest::Unit::TestCase

  def test_node_search
    nodes = manager.nodes['name' => 'vpn1']
    assert_equal 1, nodes.size
    assert_equal 'vpn1', nodes.values.first.name
  end

  def test_complex_node_search
    domain = provider.domain
    nodes = manager.nodes['dns.public' => true]
    expected = [{"domain_full"=>"ns1.#{domain}"}, {"domain_full"=>"ns2.#{domain}"}, {"domain_full"=>"vpn1.#{domain}"}, {"domain_full"=>"web1.#{domain}"}]
    assert_equal expected.size, nodes.size
    assert_equal expected, nodes.fields('domain.full')
  end



end
