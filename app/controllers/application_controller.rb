class ApplicationController < ActionController::Base
  # Populates ActiveStorage::Current.url_options from the request, so calling
  # .url on an attachment works. Rails' own ApplicationController includes this;
  # this one never did, which went unnoticed because production's S3 service is
  # public: true and needs no host. The test Disk service does, so any test that
  # attached a file and asked for its URL raised ArgumentError.
  include ActiveStorage::SetCurrent

  before_action :set_meta_data
  allow_browser versions: :modern
  layout :layout_by_resource

  # Route CarUs users to the correct destination after sign-in/sign-up
  # Must be protected to override Devise's defaults
  def after_sign_in_path_for(resource)
    case resource
    when CarOwner
      vehicles_path
    when Technician
      resource.manager? ? manager_root_path : conversations_path
    when User
      # Devise's stored location first: a User sent to sign in by an auth gate (Hermit Plus
      # favourites, say) should finish where they were going. Otherwise the player, because
      # accounts here exist for the music library and the installed PWA opens on it — the
      # home page is a detour on a device with no address bar.
      #
      # This is ALSO what decides where a new account lands.
      # Devise::RegistrationsController defines its own after_sign_up_path_for which simply
      # delegates here, and because that controller inherits from this one, its definition
      # wins: an after_sign_up_path_for written in this class is never called for the User
      # scope. It was, until this commit, and it was dead code returning "/carus" — which is
      # why a new account has been landing on the home page rather than on the CarUs demo
      # that comment claimed.
      stored_location_for(resource) || music_list_zuke_index_path
    else
      super
    end
  end

  # Where a User goes when they sign out.
  #
  # Devise's default is root_path, which drops someone out of the player and onto the
  # portfolio home page — the same one-way trip the player's sign-in link exists to fix, in
  # the other direction, and just as inescapable on a device with no address bar. They stay
  # on the player, where the public library still plays.
  #
  # Unlike after_sign_up_path_for, this one is not redefined in a Devise controller, so
  # defining it here does take effect.
  def after_sign_out_path_for(resource_or_scope)
    return music_list_zuke_index_path if resource_or_scope.to_s == "user"

    super
  end

  private

  def layout_by_resource
    if milk_admin_signed_in?
      "milk_admin"
    elsif devise_controller?
      if resource_class == CarOwner
        "car_us/car_owner"
      elsif resource_class == Technician
        "car_us/car_owner"
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
