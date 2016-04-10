require File.expand_path('../test_helper', __FILE__)

class ConfigObjectListTest < Minitest::Test

  def test_node_search
    nodes = manager.nodes['name' => 'vpn1']
    assert_equal 1, nodes.size
    assert_equal 'vpn1', nodes.values.first.name
  end

  def test_complex_node_search
    domain = provider.domain
    nodes = manager.nodes['location.country_code' => 'US']
    assert nodes.size != manager.nodes.size, 'should not return all nodes'
    assert_equal 2, nodes.size, 'should be some nodes'
    expected = manager.nodes.collect {|name, node|
      if node['location.country_code'] == 'US'
        node.domain.full
      end
    }.compact
    assert_equal expected.size, nodes.size
    assert_equal expected.sort, nodes.field('domain.full').sort
  end

  def test_nodes_like_me
    nodes = manager.nodes[:environment => nil]
    node = nodes.values.first
    assert nodes.size > 1, "should be nodes with no environment set"
    assert_equal node.nodes_like_me.values, nodes.values

    nodes = manager.nodes[:environment => "production"]
    node = nodes.values.first
    assert nodes.size > 1, "should be production nodes"
    assert_equal node.nodes_like_me.values, nodes.values
  end

end
