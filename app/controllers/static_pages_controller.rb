class StaticPagesController < ApplicationController
  def index
    @latest_articles = Blog.published.sorted.includes(:blog_category).limit(2)
    @lab_feed = Github::FeedService.fetch(limit: 4)
  end

  def gemini_pro; end

  def rocky_audio; end
end
