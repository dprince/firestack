require File.dirname(__FILE__) + '/helper'

class TestLimits < Test::Unit::TestCase

  def setup
    @conn=Helper::get_connection
  end

  def test_list

    assert_not_nil @conn.limits

  end

end
