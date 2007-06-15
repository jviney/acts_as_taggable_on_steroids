class Tag < ActiveRecord::Base
  has_many :taggings
  
  class << self
    delegate :delimiter, :delimeter=, :to => TagList
  end
  
  def ==(object)
    super || (object.is_a?(Tag) && name == object.name)
  end
  
  def to_s
    name
  end
  
  def count
    read_attribute(:count).to_i
  end
end
