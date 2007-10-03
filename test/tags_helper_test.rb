require File.dirname(__FILE__) + '/abstract_unit'

class TagsHelperTest < Test::Unit::TestCase
  fixtures :tags, :taggings, :posts
  
  include TagsHelper
  
  def test_tag_cloud
    cloud_elements = []
    
    tag_cloud(Post.tag_counts, %w(css1 css2 css3 css4)) do |tag, css_class|
      cloud_elements << [tag, css_class]
    end
    
    assert_equal [
      [tags(:good), "css2"],
      [tags(:bad), "css1"],
      [tags(:nature), "css4"],
      [tags(:question), "css1"]
    ], cloud_elements
  end
end
