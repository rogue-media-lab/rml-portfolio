class StaticPagesController < ApplicationController
  def index
    @featured_projects = Project.where(featured: true).order(updated_at: :desc).pluck(:short_title, :short_description).map do |title, description|
      {
        title: title,
        description: description,
        path: "/#{title.parameterize}"
      }
    end
  end

  def gemini_pro; end
end
