require File.dirname(__FILE__) + '/helper'

class TestImages < Test::Unit::TestCase

  def setup
    @cs=Helper::get_connection
  end

  def test_list

    @cs.images.each do |image|
      assert_not_equal(0, image[:id].to_i)
      assert_not_nil(image[:name])
      assert_equal("ACTIVE", image[:status])
    end

  end

# FIXME resolve date issue with images
#  def test_get
#
#    image=@cs.image(1)
#
#  end

end
