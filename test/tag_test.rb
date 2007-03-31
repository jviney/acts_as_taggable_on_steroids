require File.dirname(__FILE__) + '/abstract_unit'

class TagTest < Test::Unit::TestCase
  fixtures :tags, :taggings, :users, :photos, :posts
  
  def test_taggings
    assert_equal [taggings(:jonathan_sky_good), taggings(:sam_flowers_good), taggings(:sam_flower_good)], tags(:good).taggings
    assert_equal [taggings(:sam_ground_bad), taggings(:jonathan_bad_cat_bad)], tags(:bad).taggings
  end
  
  def test_tagged
    assert_equal [posts(:jonathan_sky), posts(:sam_flowers), photos(:sam_flower)], tags(:good).tagged
    assert_equal [posts(:sam_ground), photos(:jonathan_bad_cat)], tags(:bad).tagged
  end
  
  def test_tag
    assert !tags(:good).tagged.include?(posts(:jonathan_grass))
    tags(:good).tag(posts(:jonathan_grass))
    assert tags(:good).tagged.include?(posts(:jonathan_grass))
  end
  
  def test_parse_leaves_string_unchanged
    tags = '"One  ", Two'
    original = tags.dup
    Tag.parse(tags)
    assert_equal tags, original
  end
  
  def test_parse_single_tag
    assert_equal %w(Fun), Tag.parse("Fun")
    assert_equal %w(Fun), Tag.parse('"Fun"')
  end
  
  def test_parse_blank
    assert_equal [], Tag.parse(nil)
    assert_equal [], Tag.parse("")
  end
  
  def test_parse_single_quoted_tag
    assert_equal ['with, comma'], Tag.parse('"with, comma"')
  end
  
  def test_spaces_do_not_delineate
    assert_equal ['A B', 'C'], Tag.parse('A B, C')
  end
  
  def test_parse_multiple_tags
    assert_equivalent %w(Alpha Beta Delta Gamma), Tag.parse("Alpha, Beta, Gamma, Delta").sort
  end
  
  def test_parse_multiple_tags_with_quotes
    assert_equivalent %w(Alpha Beta Delta Gamma), Tag.parse('Alpha,  "Beta",  Gamma , "Delta"').sort
  end
  
  def test_parse_multiple_tags_with_quote_and_commas
    assert_equivalent ['Alpha, Beta', 'Delta', 'Gamma, something'], Tag.parse('"Alpha, Beta", Delta, "Gamma, something"')
  end
  
  def test_parse_removes_white_space
    assert_equivalent %w(Alpha Beta), Tag.parse('" Alpha   ", "Beta  "')
    assert_equivalent %w(Alpha Beta), Tag.parse('  Alpha,  Beta ')
  end
  
  def test_alternative_delimiter
    Tag.delimiter = " "
    
    assert_equal %w(One Two), Tag.parse("One Two")
    assert_equal ['One two', 'three', 'four'], Tag.parse('"One two" three four')
  ensure
    Tag.delimiter = ","
  end
  
  def test_to_s
    assert_equal tags(:good).name, tags(:good).to_s
  end
  
  def test_equality
    assert_equal tags(:good), tags(:good)
    assert_equal Tag.find(1), Tag.find(1)
    assert_equal Tag.new(:name => 'A'), Tag.new(:name => 'A')
    assert_not_equal Tag.new(:name => 'A'), Tag.new(:name => 'B')
  end
end
