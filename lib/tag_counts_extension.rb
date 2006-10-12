module TagCountsExtension
  # Options will be passed to the tag_counts method on the association's class
  def tag_counts(options = {})
    load_target
    return [] if target.blank?
    
    key_condition = "#{@reflection.table_name}.#{@reflection.primary_key_name} = #{target.first.send(@reflection.primary_key_name)}"
    
    options[:conditions] = if options[:conditions]
      sanitize_sql(options[:conditions]) + " and #{key_condition}"
    else
      key_condition
    end
    
    @reflection.klass.tag_counts(options)
  end
end
