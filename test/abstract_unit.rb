require 'test/unit'

begin
  require File.dirname(__FILE__) + '/../../../../config/environment'
rescue LoadError
  require 'rubygems'
  require_gem 'activerecord'
  require_gem 'actionpack'
end

# Search for fixtures first
fixture_path = File.dirname(__FILE__) + '/fixtures/'
begin
  Dependencies.load_paths.insert(0, fixture_path)
rescue
  $LOAD_PATH.unshift(fixture_path)
end

require 'active_record/fixtures'

require File.dirname(__FILE__) + '/../lib/acts_as_taggable'
require_dependency File.dirname(__FILE__) + '/../lib/tag_list'

ActiveRecord::Base.logger = Logger.new(File.dirname(__FILE__) + '/debug.log')
ActiveRecord::Base.configurations = YAML::load(IO.read(File.dirname(__FILE__) + '/database.yml'))
ActiveRecord::Base.establish_connection(ENV['DB'] || 'mysql')

load(File.dirname(__FILE__) + '/schema.rb')

Test::Unit::TestCase.fixture_path = fixture_path

class Test::Unit::TestCase #:nodoc:
  self.use_transactional_fixtures = true
  self.use_instantiated_fixtures  = false
  
  def assert_equivalent(expected, actual, message = nil)
    if expected.first.is_a?(ActiveRecord::Base)
      assert_equal expected.sort_by(&:id), actual.sort_by(&:id), message
    else
      assert_equal expected.sort, actual.sort, message
    end
  end
  
  def assert_tag_counts(tags, expected_values)
    # Map the tag fixture names to real tag names
    expected_values = expected_values.inject({}) do |hash, (tag, count)|
      hash[tags(tag).name] = count
      hash
    end
    
    tags.each do |tag|
      value = expected_values.delete(tag.name)
      assert_not_nil value, "Expected count for #{tag.name} was not provided" if value.nil?
      assert_equal value, tag.count, "Expected value of #{value} for #{tag.name}, but was #{tag.count}"
    end
    
    unless expected_values.empty?
      assert false, "The following tag counts were not present: #{expected_values.inspect}"
    end
  end
  
  def assert_queries(num = 1)
    $query_count = 0
    yield
  ensure
    assert_equal num, $query_count, "#{$query_count} instead of #{num} queries were executed."
  end

  def assert_no_queries(&block)
    assert_queries(0, &block)
  end
end

ActiveRecord::Base.connection.class.class_eval do  
  def execute_with_counting(sql, name = nil, &block)
    $query_count ||= 0
    $query_count += 1
    execute_without_counting(sql, name, &block)
  end
  
  alias_method_chain :execute, :counting
end
