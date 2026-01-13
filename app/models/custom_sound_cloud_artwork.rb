class CustomSoundCloudArtwork < ApplicationRecord
  has_one_attached :custom_image

  validates :soundcloud_track_id, presence: true, uniqueness: true
  validates :track_title, presence: true

  # Class method to find custom artwork by SoundCloud track ID
  # Returns the custom image URL or nil
  def self.custom_image_for(soundcloud_track_id)
    artwork = find_by(soundcloud_track_id: soundcloud_track_id)
    return nil unless artwork&.custom_image&.attached?

    # Return the S3 URL (or Rails storage proxy URL)
    Rails.application.routes.url_helpers.rails_blob_url(artwork.custom_image, only_path: true)
  end

  # Instance method to get the image variant for grid display
  def grid_image_url
    return nil unless custom_image.attached?
    Rails.application.routes.url_helpers.rails_blob_url(
      custom_image.variant(resize_to_limit: [400, 400]),
      only_path: true
    )
  end

  # Full size image URL
  def full_image_url
    return nil unless custom_image.attached?
    Rails.application.routes.url_helpers.rails_blob_url(custom_image, only_path: true)
  end
end
