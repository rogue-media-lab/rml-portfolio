# frozen_string_literal: true

# This concern provides a standardized interface for authentication and
# authorization within the Zuke music player module. By centralizing
# these checks, we make the Zuke module portable; when moving to a
# new platform, you only need to update this concern to match the
# host application's authentication system (e.g., swapping milk_admin for user).
module ZukeAuth
  extend ActiveSupport::Concern

  included do
    # Helper method to expose admin status to views
    helper_method :zuke_admin?
  end

  private

  # Returns true if the currently logged-in entity has administrative
  # privileges over the music collection.
  def zuke_admin?
    # In the Portfolio, administrators are MilkAdmins.
    # In a new platform, this might be `current_user&.admin?`.
    milk_admin_signed_in?
  end

  # A before_action filter to ensure the user is an authorized music administrator.
  def authenticate_zuke_admin!
    # In the Portfolio, we leverage Devise's built-in helper.
    authenticate_milk_admin!
  end

  # Returns the current authorized administrator object.
  def current_zuke_admin
    current_milk_admin
  end
end
