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
        #   :match_all - Find models that match all of the given tags, not just one
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
          
          conditions = []
          conditions << sanitize_sql(options.delete(:conditions)) if options[:conditions]
          
          taggings_alias, tags_alias = "#{table_name}_taggings", "#{table_name}_tags"
          
          if options.delete(:exclude)
            tags_conditions = tags.map { |t| sanitize_sql(["#{Tag.table_name}.name LIKE ?", t]) }.join(" OR ")
            conditions << sanitize_sql(["#{table_name}.id NOT IN (SELECT #{Tagging.table_name}.taggable_id FROM #{Tagging.table_name} LEFT OUTER JOIN #{Tag.table_name} ON #{Tagging.table_name}.tag_id = #{Tag.table_name}.id WHERE (#{tags_conditions}) AND #{Tagging.table_name}.taggable_type = #{quote_value(base_class.name)})", tags])
          else
            conditions << tags.map { |t| sanitize_sql(["#{tags_alias}.name LIKE ?", t]) }.join(" OR ")
            
            if options.delete(:match_all)
              group = "#{taggings_alias}.taggable_id HAVING COUNT(#{taggings_alias}.taggable_id) = #{tags.size}"
            end
          end
          
          { :select => "DISTINCT #{table_name}.*",
            :joins => "LEFT OUTER JOIN #{Tagging.table_name} #{taggings_alias} ON #{taggings_alias}.taggable_id = #{table_name}.#{primary_key} AND #{taggings_alias}.taggable_type = #{quote_value(base_class.name)} " +
                      "LEFT OUTER JOIN #{Tag.table_name} #{tags_alias} ON #{tags_alias}.id = #{taggings_alias}.tag_id",
            :conditions => conditions.join(" AND "),
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
        #  :at_most - Exclude tags with a frequency greater than the given value
        def tag_counts(*args)
          Tag.find(:all, find_options_for_tag_counts(*args))
        end
        
        def find_options_for_tag_counts(options = {})
          options.assert_valid_keys :start_at, :end_at, :conditions, :at_least, :at_most, :order, :limit

          scope = scope(:find)
          start_at = sanitize_sql(["#{Tagging.table_name}.created_at >= ?", options[:start_at]]) if options[:start_at]
          end_at = sanitize_sql(["#{Tagging.table_name}.created_at <= ?", options[:end_at]]) if options[:end_at]
          
          conditions = [
            "#{Tagging.table_name}.taggable_type = #{quote_value(base_class.name)}",
            options[:conditions],
            scope && scope[:conditions],
            start_at,
            end_at
          ].compact.join(' AND ')
          
          at_least  = sanitize_sql(['COUNT(*) >= ?', options[:at_least]]) if options[:at_least]
          at_most   = sanitize_sql(['COUNT(*) <= ?', options[:at_most]]) if options[:at_most]
          having    = [at_least, at_most].compact.join(' AND ')
          group_by  = "#{Tag.table_name}.id, #{Tag.table_name}.name HAVING COUNT(*) > 0"
          group_by << " AND #{having}" unless having.blank?
          
          { :select     => "#{Tag.table_name}.id, #{Tag.table_name}.name, COUNT(*) AS count", 
            :joins      => "LEFT OUTER JOIN #{Tagging.table_name} ON #{Tag.table_name}.id = #{Tagging.table_name}.tag_id LEFT OUTER JOIN #{table_name} ON #{table_name}.#{primary_key} = #{Tagging.table_name}.taggable_id",
            :conditions => conditions,
            :group      => group_by,
            :order      => options[:order],
            :limit      => options[:limit]
          }
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
              tags << Tag.find_or_create_with_like_by_name(new_tag_name)
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
