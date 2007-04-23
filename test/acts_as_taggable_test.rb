require File.dirname(__FILE__) + '/abstract_unit'

class ActsAsTaggableOnSteroidsTest < Test::Unit::TestCase
  fixtures :tags, :taggings, :posts, :users, :photos
  
  def test_find_tagged_with
    assert_equivalent [posts(:jonathan_sky), posts(:sam_flowers)], Post.find_tagged_with('"Very good"')
    assert_equal Post.find_tagged_with('"Very good"'), Post.find_tagged_with(['Very good'])
    assert_equal Post.find_tagged_with('"Very good"'), Post.find_tagged_with([tags(:good)])
    
    assert_equivalent [photos(:jonathan_dog), photos(:sam_flower), photos(:sam_sky)], Photo.find_tagged_with('Nature')
    assert_equal Photo.find_tagged_with('Nature'), Photo.find_tagged_with(['Nature'])
    assert_equal Photo.find_tagged_with('Nature'), Photo.find_tagged_with([tags(:nature)])
    
    assert_equivalent [photos(:jonathan_bad_cat), photos(:jonathan_dog), photos(:jonathan_questioning_dog)], Photo.find_tagged_with('"Crazy animal" Bad')
    assert_equal Photo.find_tagged_with('"Crazy animal" Bad'), Photo.find_tagged_with(['Crazy animal', 'Bad'])
    assert_equal Photo.find_tagged_with('"Crazy animal" Bad'), Photo.find_tagged_with([tags(:animal), tags(:bad)])
  end
  
  def test_find_tagged_with_nonexistant_tags
    assert_equal [], Post.find_tagged_with('ABCDEFG')
    assert_equal [], Photo.find_tagged_with(['HIJKLM'])
    assert_equal [], Photo.find_tagged_with([Tag.new(:name => 'unsaved tag')])
  end
  
  def test_find_tagged_with_matching_all_tags
    assert_equivalent [photos(:jonathan_dog)], Photo.find_tagged_with('Crazy animal, "Nature"', :match_all => true)
    assert_equivalent [posts(:jonathan_sky), posts(:sam_flowers)], Post.find_tagged_with(['Very good', 'Nature'], :match_all => true)
  end
  
  def test_basic_tag_counts_on_class
    assert_tag_counts Post.tag_counts, :good => 2, :nature => 5, :question => 1, :bad => 1
    assert_tag_counts Photo.tag_counts, :good => 1, :nature => 3, :question => 1, :bad => 1, :animal => 3
  end
  
  def test_tag_counts_on_class_with_date_conditions
    assert_tag_counts Post.tag_counts(:start_at => Date.new(2006, 8, 4)), :good => 1, :nature => 3, :question => 1, :bad => 1
    assert_tag_counts Post.tag_counts(:end_at => Date.new(2006, 8, 6)), :good => 1, :nature => 4, :question => 1
    assert_tag_counts Post.tag_counts(:start_at => Date.new(2006, 8, 5), :end_at => Date.new(2006, 8, 8)), :good => 1, :nature => 2, :bad => 1
    
    assert_tag_counts Photo.tag_counts(:start_at => Date.new(2006, 8, 12), :end_at => Date.new(2006, 8, 17)), :good => 1, :nature => 1, :bad => 1, :question => 1, :animal => 2
  end
  
  def test_tag_counts_on_class_with_frequencies
    assert_tag_counts Photo.tag_counts(:at_least => 2), :nature => 3, :animal => 3
    assert_tag_counts Photo.tag_counts(:at_most => 2), :good => 1, :question => 1, :bad => 1
  end
  
  def test_tag_counts_with_limit
    assert_equal 2, Photo.tag_counts(:limit => 2).size
    assert_equal 1, Post.tag_counts(:at_least => 4, :limit => 2).size
  end
  
  def test_tag_counts_with_limit_and_order
    assert_equal [tags(:nature), tags(:good)], Post.tag_counts(:order => 'count desc', :limit => 2)
  end
  
  def test_tag_counts_on_association
    assert_tag_counts users(:jonathan).posts.tag_counts, :good => 1, :nature => 3, :question => 1
    assert_tag_counts users(:sam).posts.tag_counts, :good => 1, :nature => 2, :bad => 1
    
    assert_tag_counts users(:jonathan).photos.tag_counts, :animal => 3, :nature => 1, :question => 1, :bad => 1
    assert_tag_counts users(:sam).photos.tag_counts, :nature => 2, :good => 1
  end
  
  def test_tag_counts_on_association_with_options
    assert_equal [], users(:jonathan).posts.tag_counts(:conditions => '1=0')
    assert_tag_counts users(:jonathan).posts.tag_counts(:at_most => 2), :good => 1, :question => 1
  end
  
  def test_tag_list
    assert_equivalent Tag.parse('"Very good", Nature'), Tag.parse(posts(:jonathan_sky).tag_list)
    assert_equivalent Tag.parse('Bad, "Crazy animal"'), Tag.parse(photos(:jonathan_bad_cat).tag_list)
  end
  
  def test_reassign_tag_list
    assert_equivalent Tag.parse('Nature, Question'), Tag.parse(posts(:jonathan_rain).tag_list)
    assert posts(:jonathan_rain).update_attributes(:tag_list => posts(:jonathan_rain).tag_list)
    assert_equivalent Tag.parse('Nature, Question'), Tag.parse(posts(:jonathan_rain).tag_list)
  end
  
  def test_assign_new_tags
    assert_equivalent Tag.parse('"Very good", Nature'), Tag.parse(posts(:jonathan_sky).tag_list)
    assert posts(:jonathan_sky).update_attributes(:tag_list => "#{posts(:jonathan_sky).tag_list}, One, Two")
    assert_equivalent Tag.parse('"Very good", Nature, One, Two'), Tag.parse(posts(:jonathan_sky).tag_list)
  end
  
  def test_duplicate_tags_ignored
    assert posts(:jonathan_sky).update_attributes(:tag_list => "Test, Test")
    assert_equal "Test", posts(:jonathan_sky).tag_list
    assert posts(:jonathan_sky).update_attributes(:tag_list => "Test, Test, Test")
    assert_equal "Test", posts(:jonathan_sky).reload.tag_list
  end
  
  def test_remove_tag
    assert_equivalent Tag.parse('"Very good", Nature'), Tag.parse(posts(:jonathan_sky).tag_list)
    assert posts(:jonathan_sky).update_attributes(:tag_list => "Nature")
    assert_equivalent Tag.parse('Nature'), Tag.parse(posts(:jonathan_sky).tag_list)
  end
  
  def test_remove_and_add_tag
    assert_equivalent Tag.parse('"Very good", Nature'), Tag.parse(posts(:jonathan_sky).tag_list)
    assert posts(:jonathan_sky).update_attributes(:tag_list => "Nature, Beautiful")
    assert_equivalent Tag.parse('Nature, Beautiful'), Tag.parse(posts(:jonathan_sky).tag_list)
  end
  
  def test_tags_not_saved_if_validation_fails
    assert_equivalent Tag.parse('"Very good", Nature'), Tag.parse(posts(:jonathan_sky).tag_list)
    assert !posts(:jonathan_sky).update_attributes(:tag_list => "One Two", :text => "")
    assert_equivalent Tag.parse('"Very good", Nature'), Tag.parse(Post.find(posts(:jonathan_sky).id).tag_list)
  end
  
  def test_tag_list_accessors_on_new_record
    p = Post.new(:text => 'Test')
    
    assert_equal "", p.tag_list
    p.tag_list = "One, Two"
    assert_equal "One, Two", p.tag_list
  end
  
  def test_read_tag_list_with_commas
    assert ["Question, Crazy animal", "Crazy animal, Question"].include?(photos(:jonathan_questioning_dog).tag_list)
  end
  
  def test_read_tag_list_with_alternative_delimiter
    Tag.delimiter = " "
    
    assert ['Question "Crazy animal"', '"Crazy animal" Question'].include?(photos(:jonathan_questioning_dog).tag_list)
  end
  
  def test_clear_tag_list_with_nil
    p = photos(:jonathan_questioning_dog)
    
    assert !p.tag_list.blank?
    assert p.update_attributes(:tag_list => nil)
    assert p.tag_list.blank?
    
    assert p.reload.tag_list.blank?
    assert Photo.find(p.id).tag_list.blank?
  end
  
  def test_clear_tag_list_with_string
    p = photos(:jonathan_questioning_dog)
    
    assert !p.tag_list.blank?
    assert p.update_attributes(:tag_list => '  ')
    assert p.tag_list.blank?
    
    assert p.reload.tag_list.blank?
    assert Photo.find(p.id).tag_list.blank?
  end
  
  def test_tag_list_reset_on_reload
    p = photos(:jonathan_questioning_dog)
    assert !p.tag_list.blank?
    p.tag_list = nil
    assert p.tag_list.blank?
    assert !p.reload.tag_list.blank?
  end
  
  def test_include_tags_on_find_tagged_with
    assert_nothing_raised do
      Photo.find_tagged_with('Nature', :include => :tags)
      Photo.find_tagged_with("Nature", :include => { :taggings => :tag })
    end
  end
end
