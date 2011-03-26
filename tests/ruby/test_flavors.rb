require File.dirname(__FILE__) + '/helper'

class TestFlavors < Test::Unit::TestCase

  def setup
    @cs=Helper::get_connection
  end

  def test_list

    @cs.flavors.each do |flavor|
      assert_not_equal(0, flavor[:id].to_i)
      assert_not_nil(flavor[:name])
      assert_not_nil(flavor[:ram])
      assert_not_nil(flavor[:disk])
    end

  end

  def test_get

    flavor = @cs.flavor(1)
    assert_not_equal(0, flavor.id.to_i)
    assert_not_nil(flavor.name)
    assert_not_nil(flavor.ram)
    assert_not_nil(flavor.disk)

  end

end
