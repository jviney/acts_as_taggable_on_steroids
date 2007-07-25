require File.dirname(__FILE__) + '/abstract_unit'

class TagListTest < Test::Unit::TestCase
  def test_blank?
    assert TagList.new.blank?
  end
  
  def test_equality
    assert_equal TagList.new, TagList.new
    assert_equal TagList.new("Tag"), TagList.new("Tag")
    
    assert_not_equal TagList.new, ""
    assert_not_equal TagList.new, TagList.new("Tag")
  end
  
  def test_parse_leaves_string_unchanged
    tags = '"One  ", Two'
    original = tags.dup
    TagList.parse(tags)
    assert_equal tags, original
  end
  
  def test_from_single_name
    assert_equal %w(Fun), TagList.from("Fun").names
    assert_equal %w(Fun), TagList.from('"Fun"').names
  end
  
  def test_from_blank
    assert_equal [], TagList.from(nil).names
    assert_equal [], TagList.from("").names
  end
  
  def test_from_single_quoted_tag
    assert_equal ['with, comma'], TagList.from('"with, comma"').names
  end
  
  def test_spaces_do_not_delineate
    assert_equal ['A B', 'C'], TagList.from('A B, C').names
  end
  
  def test_from_multiple_tags
    assert_equivalent %w(Alpha Beta Delta Gamma), TagList.from("Alpha, Beta, Delta, Gamma").names.sort
  end
  
  def test_from_multiple_tags_with_quotes
    assert_equivalent %w(Alpha Beta Delta Gamma), TagList.from('Alpha,  "Beta",  Gamma , "Delta"').names.sort
  end
  
  def test_from_with_single_quotes
    assert_equivalent ['A B', 'C'], TagList.from("'A B', C").names.sort
  end
  
  def test_from_multiple_tags_with_quote_and_commas
    assert_equivalent ['Alpha, Beta', 'Delta', 'Gamma, something'], TagList.from('"Alpha, Beta", Delta, "Gamma, something"').names
  end
  
  def test_from_removes_white_space
    assert_equivalent %w(Alpha Beta), TagList.from('" Alpha   ", "Beta  "').names
    assert_equivalent %w(Alpha Beta), TagList.from('  Alpha,  Beta ').names
  end
  
  def test_alternative_delimiter
    TagList.delimiter = " "
    
    assert_equal %w(One Two), TagList.from("One Two").names
    assert_equal ['One two', 'three', 'four'], TagList.from('"One two" three four').names
  ensure
    TagList.delimiter = ","
  end
  
  def test_duplicate_tags_removed
    assert_equal %w(One), TagList.from("One, One").names
  end
  
  def test_to_s_with_commas
    assert_equal "Question, Crazy Animal", TagList.new(["Question", "Crazy Animal"]).to_s
  end
  
  def test_to_s_with_alternative_delimiter
    TagList.delimiter = " "
    
    assert_equal '"Crazy Animal" Question', TagList.new(["Crazy Animal", "Question"]).to_s
  ensure
    TagList.delimiter = ","
  end
  
  def test_add
    tag_list = TagList.new("One")
    assert_equal %w(One), tag_list.names
    
    tag_list.add("Two")
    assert_equal %w(One Two), tag_list.names
  end
  
  def test_remove
    tag_list = TagList.new("One", "Two")
    assert_equal %w(One Two), tag_list.names
    
    tag_list.remove("One")
    assert_equal %w(Two), tag_list.names
  end
end
