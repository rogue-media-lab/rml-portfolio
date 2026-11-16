class Song < ApplicationRecord
  has_one_attached :image
  has_one_attached :banner_video
  # The full track. NEVER served on a public surface — see .playable below. It
  # exists so the library keeps the master, and so the admin surface can play it.
  has_one_attached :audio_file
  # A 30-second cut of audio_file, with fades. This is what the public player
  # serves; stopping at 30s in the player is not a limit, because the file on the
  # page IS 30 seconds. Cut by Zuke::PreviewCutter (bin/zuke-cut-preview), which
  # Maestro runs before upload so the server never downloads the full track.
  # Spec: zuke previews, 2026-11-14.
  has_one_attached :preview_audio
  # Waveforms are per file, not per song. The preview's waveform is a SEPARATE
  # attachment from the full track's: generating one onto the other would make
  # the scrubber describe a file it is not playing.
  has_one_attached :waveform_data
  has_one_attached :preview_waveform_data
  belongs_to :artist
  belongs_to :album, optional: true, inverse_of: :songs

  has_many :song_genres, dependent: :destroy
  has_many :genres, through: :song_genres
  has_and_belongs_to_many :users

  has_many :playlist_songs, dependent: :destroy
  has_many :playlists, through: :playlist_songs

  accepts_nested_attributes_for :artist
  accepts_nested_attributes_for :album

  validates :title, presence: true
  validates :artist, presence: true

  # Songs that can actually be played *by the public player*.
  #
  # The public player serves the preview, so a preview is what makes a song
  # playable. A song with only the full track has nothing the public surface may
  # emit, and the smart-image component renders a play affordance
  # unconditionally — so it would become a card that dispatched an empty URL on
  # click. The scope and the predicate are the two expressions of one rule (SQL
  # for relations, Ruby for in-memory collections); nothing else restates it.
  #
  # Consequence, deliberate: on the day this ships, songs that have not been
  # backfilled with a preview disappear from the public player. Backfill before
  # deploying, not after.
  scope :playable, -> { joins(:preview_audio_attachment) }

  # The same rule for a single in-memory record, so the Ruby path cannot drift
  # from the scope.
  def playable?
    preview_audio.attached?
  end

  # What a song collection must preload before being serialized through
  # SongPresenter — every attachment it reads, blobs included, plus the artist.
  # `includes(songs: [:image_attachment])` loads attachment rows only; the blob
  # lookup still fires per song unless it is `{ attachment: :blob }`.
  #
  # audio_file and waveform_data are deliberately ABSENT. Nothing on a public
  # surface may read them, so preloading them here would paper over a leak
  # instead of surfacing one — a leaked full-track URL should be a failing test,
  # not a quiet extra query.
  SERIALIZATION_INCLUDES = [
    :artist,
    { image_attachment: :blob },
    { preview_audio_attachment: :blob },
    { preview_waveform_data_attachment: :blob },
    { banner_video_attachment: :blob }
  ].freeze

  delegate :name, to: :artist, prefix: true
  delegate :title, to: :album, prefix: true

  before_validation :associate_album_artist

  after_commit :schedule_waveform_generation, on: %i[create update]
  after_commit :schedule_preview_generation, on: %i[create update]

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
    image.variant(resize_to_limit: [ 400, 400 ], format: :webp)
  end

  private

  # Each attachment gets its own waveform job. A preview and a full track are
  # different audio, so one JSON cannot describe both.
  def schedule_waveform_generation
    GenerateWaveformJob.perform_later(self) if newly_attached?(:audio_file)
    GenerateWaveformJob.perform_later(self, "preview_audio") if newly_attached?(:preview_audio)
  end

  # Enqueues the preview cut whenever a master is attached or replaced.
  #
  # This is the wire that closes the admin-upload hole: MilkAdmin's form attaches
  # an audio_file and nothing else, so without this the song would be created,
  # saved, and then silently absent from every public surface, because .playable
  # requires a preview.
  #
  # It only enqueues. Deciding whether an existing preview is stale means
  # destroying attachments, and destroying one inside after_commit re-enters the
  # commit chain — which is a stack overflow, not a purge. GeneratePreviewJob owns
  # that decision, including the replacement case.
  #
  # It runs on production's :async adapter, i.e. on a thread inside the web dyno
  # rather than on a worker. That is acceptable here — an attached master is a
  # deliberate human action and rare — and it is strictly better than a song that
  # saves successfully and can never be played.
  def schedule_preview_generation
    return unless newly_attached?(:audio_file)

    GeneratePreviewJob.perform_later(self)
  end

  # The blob's `saved_change_to_id?` confirms the file was just created, so a
  # save that touches anything else does not re-queue a waveform.
  def newly_attached?(name)
    attachment = public_send(name)
    attachment.attached? && attachment.attachment.blob.saved_change_to_id?
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
