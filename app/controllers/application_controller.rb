class ApplicationController < ActionController::Base
  before_action :set_meta_data
  allow_browser versions: :modern
  layout :layout_by_resource

  # Route CarUs users to the correct destination after sign-in/sign-up
  # Must be protected to override Devise's defaults
  def after_sign_in_path_for(resource)
    case resource
    when CarOwner
      coupons_path
    when Technician
      manager_root_path
    else
      super
    end
  end

  def after_sign_up_path_for(resource)
    "/carus"  # safe landing — avoid auth-required pages
  end

  private

  def layout_by_resource
    if milk_admin_signed_in?
      "milk_admin"
    elsif devise_controller?
      if resource_class == CarOwner
        "car_us/car_owner"
      elsif resource_class == Technician
        "car_us/technician"
      else
        "application"
      end
    else
      "application"
    end
  end

  def set_meta_data
    set_meta_tags site: "https://www.roguemedialab.com",
                  title: "Rogue Media Lab | Mason Roberts",
                  reverse: true,
                  separator: "|",
                  description: "Developing the web with Ruby on Rails. Mason Roberts has built a corner of the internet to showcase what he can do as a designer and developer. This site serves as both a client hub and learning center.",
                  keywords: "Ruby, Rails, RoR, Ruby on Rails, Node, React, Vue, JavaScript, HTML, CSS, Express, PG, PostgreSQL, MongoDB, Mongoose, MERN, MEAN, MERN Stack, Full Stack, Web Development, Web Design, Web Designer, Web Developer, Mason Roberts",
                  canonical: request.original_url,
                  noindex: !Rails.env.production?,
                  og: {
                    title: :title,
                    type: "website",
                    url: request.original_url,
                    image: "https://milk-blog.s3.us-east-2.amazonaws.com/og-image.png",
                    image_alt: "The Rogue Media Lab",
                    site_name: "https://www.roguemedialab.com"
                  }
  end
end