class HermitPlusController < ApplicationController
  before_action :set_meta_data
  # Landing Page
  def landing
    # Video thumbnails for Season 8 Episode 1
    # TODO: Replace with database query when HermitVideo model is complete
    s3_base_url = "https://milk-blog.s3.us-east-2.amazonaws.com/hermits"

    video_filenames = [
      "bDouble0S8E1thumb.webp", "cubFanS8E1thumb.webp", "docm77S8E1thumb.webp",
      "ethoS8E1thumb.webp", "falseS8E1thumb.webp", "geminiS8E1thumb.webp",
      "scarS8E1thumb.webp", "grianS8E1thumb.webp", "hypnoS8E1thumb.webp",
      "jevinS8E1thumb.webp", "impulseS8E1thumb.webp", "iskalS8E1thumb.webp",
      "joeHillsS8E1thumb.webp", "keralisS8E1thumb.webp", "mumboS8E1thumb.webp",
      "pearlMoonS8E1thumb.webp", "rendogS8E1thumb.webp", "stressS8E1thumb.webp",
      "tangoS8E1thumb.webp", "tinS8E1thumb.webp", "welknightS8E1thumb.webp",
      "xbS8E1thumb.webp", "xisumaS8E1thumb.webp", "zedaphS8E1thumb.webp",
      "zombieS8E1thumb.webp"
    ]

    @hero_videos = video_filenames.map { |filename| { url: "#{s3_base_url}/#{filename}", filename: filename } }
    @bottom_videos = @hero_videos.first(9)
  end

  private

  # app/controllers/application_controller.rb
  def set_meta_data
    set_meta_tags site: "https://www.roguemedialab.com/hermit-plus",
                  title: "Hermit Plus | Mason Roberts",
                  reverse: true,
                  separator: "|",
                  description: "Hermit Plus is a fan site dedicated to the Hermitcraft Minecraft server and its content creators. Explore episode guides, video thumbnails, and more from Season 8 of Hermitcraft.",
                  keywords: "Hermits, Hermitcraft, Minecraft, Hermit Plus, Mason Roberts, Minecraft Server, Minecraft Episodes, Hermitcraft Season 8, Minecraft Content Creators",
                  canonical: request.original_url,
                  noindex: !Rails.env.production?,
                  og: {
                    title: :title,
                    type: "website",
                    url: request.original_url,
                    image: "https://milk-blog.s3.us-east-2.amazonaws.com/hermits/hpscreenshot.png",
                    image_alt: "Hermit Plus Landing Page",
                    site_name: "Hermit Plus"
                  }
  end
end
