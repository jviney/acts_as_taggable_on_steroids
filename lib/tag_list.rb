class TagList < Array
  cattr_accessor :delimiter
  self.delimiter = ','
  
  def initialize(*names)
    add(*names)
  end
  
  def add(*names)
    # Strip whitespace and remove blank or duplicate tags
    names.reject!(&:blank?)
    names.map!(&:strip)
    
    concat(names)
    uniq!
  end
  
  # Backwards compatibility
  def names
    self
  end
  
  def remove(*names)
    delete_if { |name| names.include?(name) }
  end
  
  def to_s
    map do |name|
      name.include?(delimiter) ? "\"#{name}\"" : name
    end.join(delimiter.ends_with?(" ") ? delimiter : "#{delimiter} ")
  end
  
  class << self
    def from(string)
      new(*parse(string))
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
