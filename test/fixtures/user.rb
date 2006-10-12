class User < ActiveRecord::Base
  has_many :posts, :extend => TagCountsExtension
  has_many :photos, :extend => TagCountsExtension
end
