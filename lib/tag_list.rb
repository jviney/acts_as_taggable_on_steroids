class TagList
  cattr_accessor :delimiter
  self.delimiter = ','
  
  attr_reader :names
  
  def initialize(*names)
    @names = []
    add(*names)
  end
  
  def add(*names)
    names = names.flatten
    
    # Strip whitespace and remove blank or duplicate tags
    names.map!(&:strip)
    names.reject!(&:blank?)
    
    @names.concat(names)
    @names.uniq!
  end
  
  def remove(*names)
    names = names.flatten
    @names.delete_if { |name| names.include?(name) }
  end
  
  def blank?
    @names.empty?
  end
  
  def to_s
    @names.map do |name|
      name.include?(delimiter) ? "\"#{name}\"" : name
    end.join(delimiter.ends_with?(" ") ? delimiter : "#{delimiter} ")
  end
  
  def ==(other)
    super || (other.is_a?(TagList) && other.names == @names)
  end
  
  class << self
    def from(string)
      new(parse(string))
    end
    
    def parse(string)
      returning [] do |names|
        string = string.to_s.dup
        
        # Parse the quoted tags
        string.gsub!(/"(.*?)"\s*#{delimiter}?\s*/) { names << $1; "" }
        string.gsub!(/'(.*?)'\s*#{delimiter}?\s*/) { names << $1; "" }
        
        names.concat(string.split(delimiter))
      end
    end
  end
end
