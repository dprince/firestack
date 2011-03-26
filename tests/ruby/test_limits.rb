require File.dirname(__FILE__) + '/helper'

class TestFlavors < Test::Unit::TestCase

  def setup
    @cs=Helper::get_connection
  end

  def test_list

    assert_not_nil @cs.limits

  end

end
