module TagsHelper
  def tag_cloud(tags, classes)
    sorted_tags = tags.sort_by(&:count)
    min, max = sorted_tags.first.count, sorted_tags.last.count
    
    tags.each do |tag|
      index = ((tag.count / max) * (classes.size - 1)).round
      yield tag, classes[index]
    end
  end
end
