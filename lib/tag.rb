class Tag < ActiveRecord::Base
  has_many :taggings
  
  cattr_accessor :delimiter
  self.delimiter = ','
  
  def self.parse(list)
    tags = []
    
    return tags if list.blank?
    list = list.dup
    
    # Parse the quoted tags
    list.gsub!(/"(.*?)"\s*#{delimiter}?\s*/) { tags << $1; "" }
    
    # Strip whitespace and remove blank tags
    (tags + list.split(delimiter)).map!(&:strip).delete_if(&:blank?)
  end
  
  # A list of all the objects tagged with this tag
  def tagged
    taggings.collect(&:taggable)
  end
  
  # Tag a taggable with this tag
  def tag(taggable)
    Tagging.create :tag_id => id, :taggable => taggable
    taggings.reset
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
