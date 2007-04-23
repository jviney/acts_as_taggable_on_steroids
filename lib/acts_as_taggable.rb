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
          
          after_save :save_tags
          
          include ActiveRecord::Acts::Taggable::InstanceMethods
          extend ActiveRecord::Acts::Taggable::SingletonMethods
          
          alias_method :reload_without_tag_list, :reload
          alias_method :reload, :reload_with_tag_list
        end
      end
      
      module SingletonMethods
        # Pass either a tag string, or an array of strings or tags
        # 
        # Options:
        #   :exclude - Find models that are not tagged with the given tags
        #   :match_all - Find models that match all of the gievn tags, not just one
        #   :conditions - A piece of SQL conditions to add to the query
        def find_tagged_with(tags, options = {})
          tags = Tag.parse(tags) if tags.is_a?(String)
          return [] if tags.empty?
          tags.map!(&:to_s)
          
          conditions = sanitize_sql(["#{table_name}_tags.name #{"NOT" if options.delete(:exclude)} IN (?)", tags])
          conditions << " AND #{sanitize_sql(options.delete(:conditions))}" if options[:conditions]
          
          group = "#{table_name}_taggings.taggable_id HAVING COUNT(#{table_name}_taggings.taggable_id) = #{tags.size}" if options.delete(:match_all)
          
          find(:all, { :select => "DISTINCT #{table_name}.*",
            :joins => "LEFT OUTER JOIN taggings #{table_name}_taggings ON #{table_name}_taggings.taggable_id = #{table_name}.#{primary_key} AND #{table_name}_taggings.taggable_type = '#{name}' " +
                      "LEFT OUTER JOIN tags #{table_name}_tags ON #{table_name}_tags.id = #{table_name}_taggings.tag_id",
            :conditions => conditions,
            :group      => group }.merge(options))
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
            "taggings.taggable_type = '#{name}'",
            options[:conditions],
            scope && scope[:conditions],
            start_at,
            end_at
          ]
          conditions = conditions.compact.join(' and ')
          
          at_least  = sanitize_sql(['count >= ?', options[:at_least]]) if options[:at_least]
          at_most   = sanitize_sql(['count <= ?', options[:at_most]]) if options[:at_most]
          having    = [at_least, at_most].compact.join(' and ')
          group_by  = 'tags.id, tags.name having count(*) > 0'
          group_by << " and #{having}" unless having.blank?

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
        attr_writer :tag_list
        
        def tag_list
          defined?(@tag_list) ? @tag_list : read_tags
        end
        
        def save_tags
          if defined?(@tag_list)
            write_tags(@tag_list)
            remove_tag_list
          end
        end
        
        def write_tags(list)
          new_tag_names = Tag.parse(list).uniq
          old_tagging_ids = []
          
          Tag.transaction do
            taggings.each do |tagging|
              index = new_tag_names.index(tagging.tag.name)
              index ? new_tag_names.delete_at(index) : old_tagging_ids << tagging.id
            end
            
            Tagging.delete_all(['id in (?)', old_tagging_ids]) if old_tagging_ids.any?
            
            # Create any new tags/taggings
            new_tag_names.each do |name|
              Tag.find_or_create_by_name(name).tag(self)
            end
            
            taggings.reset
            tags.reset
          end
          true
        end

        def read_tags
          tags.map do |tag|
            tag.name.include?(Tag.delimiter) ? "\"#{tag.name}\"" : tag.name
          end.join(Tag.delimiter.ends_with?(" ") ? Tag.delimiter : "#{Tag.delimiter} ")
        end
        
        def reload_with_tag_list(*args)
          remove_tag_list
          reload_without_tag_list(*args)
        end
        
       private
        def remove_tag_list
          remove_instance_variable(:@tag_list) if defined?(@tag_list)
        end
      end
    end
  end
end

ActiveRecord::Base.send(:include, ActiveRecord::Acts::Taggable)
