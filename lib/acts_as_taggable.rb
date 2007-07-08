module ActiveRecord
  module Acts #:nodoc:
    module Taggable #:nodoc:
      def self.included(base)
        base.extend(ClassMethods)
      end
      
      module ClassMethods
        def acts_as_taggable(options = {})
          has_many :taggings, :as => :taggable, :dependent => :destroy, :include => :tag
          has_many :tags, :through => :taggings
          
          before_save :save_cached_tag_list
          after_save :save_tags
          
          include ActiveRecord::Acts::Taggable::InstanceMethods
          extend ActiveRecord::Acts::Taggable::SingletonMethods
          
          alias_method :reload_without_tag_list, :reload
          alias_method :reload, :reload_with_tag_list
        end
        
        def cached_tag_list_column_name
          "cached_tag_list"
        end
        
        def set_cached_tag_list_column_name(value = nil, &block)
          define_attr_method :cached_tag_list_column_name, value, &block
        end
      end
      
      module SingletonMethods
        # Pass either a tag string, or an array of strings or tags
        # 
        # Options:
        #   :exclude - Find models that are not tagged with the given tags
        #   :match_all - Find models that match all of the gievn tags, not just one
        #   :conditions - A piece of SQL conditions to add to the query
        def find_options_for_tagged_with(tags, options = {})
	  tags = if tags.is_a?(String)
	    TagList.from(tags).names
	  else
	    tags.dup
	  end
	  
          tags.compact!
          tags.map!(&:to_s)
          
          return {} if tags.empty?
          
          conditions = sanitize_sql(["#{table_name}_tags.name #{"NOT" if options.delete(:exclude)} IN (?)", tags])
          conditions << " AND #{sanitize_sql(options.delete(:conditions))}" if options[:conditions]
          
          group = "#{table_name}_taggings.taggable_id HAVING COUNT(#{table_name}_taggings.taggable_id) = #{tags.size}" if options.delete(:match_all)
          
          { :select => "DISTINCT #{table_name}.*",
            :joins => "LEFT OUTER JOIN taggings #{table_name}_taggings ON #{table_name}_taggings.taggable_id = #{table_name}.#{primary_key} AND #{table_name}_taggings.taggable_type = '#{name}' " +
                      "LEFT OUTER JOIN tags #{table_name}_tags ON #{table_name}_tags.id = #{table_name}_taggings.tag_id",
            :conditions => conditions,
            :group      => group
          }.update(options)
        end
        
        def find_tagged_with(*args)
          options = find_options_for_tagged_with(*args)
          options.blank? ? [] : find(:all, options)
        end
        
        # Options:
        #  :start_at - Restrict the tags to those created after a certain time
        #  :end_at - Restrict the tags to those created before a certain time
        #  :conditions - A piece of SQL conditions to add to the query
        #  :limit - The maximum number of tags to return
        #  :order - A piece of SQL to order by. Eg 'tags.count desc' or 'taggings.created_at desc'
        #  :at_least - Exclude tags with a frequency less than the given value
        #  :at_most - Exclude tags with a frequency greater then the given value
        def tag_counts(options = {})
          options.assert_valid_keys :start_at, :end_at, :conditions, :at_least, :at_most, :order, :limit

          scope = scope(:find)
          start_at = sanitize_sql(['taggings.created_at >= ?', options[:start_at]]) if options[:start_at]
          end_at = sanitize_sql(['taggings.created_at <= ?', options[:end_at]]) if options[:end_at]
          
          conditions = [
            "taggings.taggable_type = #{quote_value(name)}",
            options[:conditions],
            scope && scope[:conditions],
            start_at,
            end_at
          ]
          conditions = conditions.compact.join(' and ')
          
          at_least  = sanitize_sql(['COUNT(*) >= ?', options[:at_least]]) if options[:at_least]
          at_most   = sanitize_sql(['COUNT(*) <= ?', options[:at_most]]) if options[:at_most]
          having    = [at_least, at_most].compact.join(' and ')
          group_by  = 'tags.id, tags.name HAVING COUNT(*) > 0'
          group_by << " AND #{having}" unless having.blank?

          Tag.find(:all,
            :select     => 'tags.id, tags.name, COUNT(*) AS count', 
            :joins      => "LEFT OUTER JOIN taggings ON tags.id = taggings.tag_id LEFT OUTER JOIN #{table_name} ON #{table_name}.#{primary_key} = taggings.taggable_id",
            :conditions => conditions,
            :group      => group_by,
            :order      => options[:order],
            :limit      => options[:limit]
          )
        end
      end
      
      module InstanceMethods
        def tag_list
          if @tag_list
            @tag_list
          elsif caching_tag_list? and !send(self.class.cached_tag_list_column_name).nil?
            @tag_list = TagList.from(send(self.class.cached_tag_list_column_name))
          else
            @tag_list = TagList.new(tags.map(&:name))
          end
        end
        
        def tag_list=(value)
          @tag_list = TagList.from(value)
        end
        
        def save_cached_tag_list
          if caching_tag_list? and !tag_list.blank?
            self[self.class.cached_tag_list_column_name] = tag_list.to_s
          end
        end
        
        def save_tags
          return unless @tag_list
          
          new_tag_names = @tag_list.names - tags.map(&:name)
          old_tags = tags.reject { |tag| @tag_list.names.include?(tag.name) }
          
          self.class.transaction do
            tags.delete(*old_tags) if old_tags.any?
            
            new_tag_names.each do |new_tag_name|
              tags << Tag.find_or_create_by_name(new_tag_name)
            end
          end
          true
        end

        def reload_with_tag_list(*args)
          @tag_list = nil
          reload_without_tag_list(*args)
        end
        
        def caching_tag_list?
          self.class.column_names.include?(self.class.cached_tag_list_column_name)
        end
      end
    end
  end
end

ActiveRecord::Base.send(:include, ActiveRecord::Acts::Taggable)
