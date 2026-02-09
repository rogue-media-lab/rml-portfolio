# frozen_string_literal: true

# Stores SoundCloud OAuth2 tokens.
# Using a database table ensures that token rotation persists across Heroku dyno restarts.
class SoundcloudToken < ApplicationRecord
  validates :access_token, presence: true
  validates :refresh_token, presence: true
  validates :client_id, presence: true

  def expired?
    return true if expires_at.nil?
    Time.now.to_i >= expires_at - 60
  end

  def self.current
    order(updated_at: :desc).first
  end
end
