require File.dirname(__FILE__) + '/helper'

class TestImages < Test::Unit::TestCase

  def setup
    @conn=Helper::get_connection
    @image_id = Helper::get_image_ref(@conn)
  end

  def test_list

    @conn.images.each do |image|
      assert_not_nil(image[:id])
      assert_not_nil(image[:name])
      assert_equal("ACTIVE", image[:status])
    end

  end

  def test_get

    image=@conn.image(@image_id)
    assert_equal(@image_id, image.id.to_s)
    assert_not_nil(image.name)
    assert_not_nil(image.updated)
    assert_not_nil(image.created)
    assert_not_nil(image.status)

  end

end
