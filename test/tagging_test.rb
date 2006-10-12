require File.dirname(__FILE__) + '/abstract_unit'

class TaggingTest < Test::Unit::TestCase
  fixtures :tags, :taggings
  
  def test_tag
    assert_equal tags(:good), taggings(:jonathan_sky_good).tag
  end
end
