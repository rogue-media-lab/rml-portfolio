class Song < ApplicationRecord
  has_one_attached :image
  has_one_attached :banner_video
  has_one_attached :audio_file
  has_one_attached :waveform_data
  belongs_to :artist
  belongs_to :album, optional: true, inverse_of: :songs

  has_many :song_genres, dependent: :destroy
  has_many :genres, through: :song_genres
  has_and_belongs_to_many :users

  has_many :playlist_songs, dependent: :destroy
  has_many :playlists, through: :playlist_songs

  accepts_nested_attributes_for :artist
  accepts_nested_attributes_for :album

  delegate :name, to: :artist, prefix: true
  delegate :title, to: :album, prefix: true

  before_validation :associate_album_artist

  after_commit :schedule_waveform_generation, on: %i[create update]

  # Ransack: Allow searching on specific attributes
  def self.ransackable_attributes(auth_object = nil)
    [ "title", "created_at", "updated_at" ]
  end

  # Custom nested attribute setters to find or create associated records
  def artist_attributes=(attributes)
    if attributes[:name].present?
      self.artist = Artist.find_or_create_by(name: attributes[:name])
    end
  end

  def album_attributes=(attributes)
    # Skip if no title provided
    return unless attributes[:title].present?

    # Ensure artist is present before processing album
    return unless artist.present?

    # Find or create the genre first if provided
    genre = if attributes.dig(:genre, :name).present?
              genre_name = attributes[:genre][:name].strip
              # Case-insensitive find to match existing genres, then create if not found
              Genre.where("LOWER(name) = LOWER(?)", genre_name).first ||
              Genre.create!(name: genre_name.titleize)
    end

    # Find or initialize the album
    album = Album.find_or_initialize_by(
      title: attributes[:title],
      artist_id: artist.id
    )

    # Update genre if it's provided and has changed
    album.genre = genre if genre && album.genre != genre

    # Save the album if it's new or has changed
    album.save if album.new_record? || album.changed?

    # Associate the album with the song
    self.album = album if album.persisted?
  end

  # Check if song has any attribution data
  def has_credits?
    image_credit.present? || image_credit_url.present? ||
    audio_source.present? || additional_credits.present?
  end

  # Generate mobile-optimized square crop based on focal point
  def mobile_image_variant
    return unless image.attached?

    # For mobile: create 640x640 retina-friendly square crop centered on focal point
    crop_params = calculate_mobile_crop

    image.variant(
      crop: crop_params,
      resize_to_limit: [ 640, 640 ],
      format: :webp
    )
  end

  def grid_image_variant
    return unless image.attached?
    image.variant(resize_to_limit: [400, 400], format: :webp)
  end

  private

  def schedule_waveform_generation
    # Trigger job only when a new audio file is attached.
    # The blob's `saved_change_to_id?` confirms it was just created.
    if audio_file.attached? && audio_file.attachment.blob.saved_change_to_id?
      GenerateWaveformJob.perform_later(self)
    end
  end

  def calculate_mobile_crop
    return [ 0, 0, 640, 640 ] unless image.attached?

    # Get actual image dimensions from blob metadata
    metadata = image.blob.metadata
    source_width = metadata["width"] || 1024
    source_height = metadata["height"] || 574

    # Use the smaller dimension for square crop
    target_size = [ source_width, source_height ].min

    # Get focal point (defaults to center if not set)
    fx = (focal_point_x || 0.5) * source_width
    fy = (focal_point_y || 0.5) * source_height

    # Calculate crop box centered on focal point
    # Ensure crop box stays within image bounds
    left = [ [ fx - target_size / 2, 0 ].max, source_width - target_size ].min
    top = [ [ fy - target_size / 2, 0 ].max, source_height - target_size ].min

    # Return libvips crop format: [left, top, width, height]
    [ left.to_i, top.to_i, target_size, target_size ]
  end

  def associate_album_artist
    # Album artist is already set by find_or_create_by in process_nested_attributes
    # This callback ensures consistency but doesn't save to avoid validation loops
    if artist.present? && album.present? && album.artist_id != artist.id
      album.artist = artist
    end
  end
end
