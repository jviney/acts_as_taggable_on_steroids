require 'rails/generators'
require 'rails/generators/migration'

class ActsAsTaggableMigrationGenerator < Rails::Generators::Base 
  include Rails::Generators::Migration

  def self.source_root
     @source_root ||= File.expand_path(File.join(File.dirname(__FILE__), 'templates'))
  end

  def self.next_migration_number(dirname)
     Time.now.strftime("%Y%m%d%H%M%S")
  end

  def create_migration
     migration_template "migration.rb", File.join("db/migrate", "#{file_name}.rb")
  end

  protected

  def file_name
    "acts_as_taggable_migration"
  end
end
