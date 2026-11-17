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

  # The files a caller may ask for by name. "master" first because that is the
  # default — asking for a song's file means the song.
  DOWNLOADABLE_FILES = {
    "master" => :audio_file,
    "preview" => :preview_audio,
    "image" => :image,
    "banner_video" => :banner_video
  }.freeze

  # The attachment behind +name+, or nil if the name is unknown or nothing is
  # attached. An unknown name is nil rather than a default, so a typo'd ?file=
  # cannot quietly hand back the master.
  def downloadable_file(name = nil)
    attachment_name = DOWNLOADABLE_FILES[name.to_s.presence || "master"]
    return nil unless attachment_name

    attachment = public_send(attachment_name)
    attachment if attachment.attached?
  end

  # Who may use this song's full audio — hearing it in full, or taking a copy of it.
  #
  # Three listeners qualify. A librarian of the collection — the MilkAdmin who curates
  # these songs and the previews the public hears, and who therefore hears all of them. A
  # user whose own upload this is. And a user flagged `can_download`, for accounts allowed
  # to pull from the curated library. Anonymous callers get nothing.
  #
  # `zuke_librarian?` is asked on the listener rather than tested as a MilkAdmin type, so
  # the model stays unaware of which class the host application signs administrators in
  # with. ZukeAuth is where that translation lives, and where it would change if Zuke
  # moved to another platform.
  #
  # The player's presenter asks this. The session download endpoint asks it through
  # Song#downloadable_by?. The token-authenticated API endpoint deliberately does not —
  # see Api::V1::SongsController#download.
  def full_audio_for?(listener)
    return false if listener.nil?
    return true if Song.librarian?(listener)

    # The ownership rows answer both questions below, so they are read once. With :users
    # preloaded — it is in SERIALIZATION_INCLUDES, and this is why — that read is free;
    # without, it is a single query rather than the one-per-song `exists?` this used to run.
    owners = users.to_a

    # Your own upload is yours.
    return true if owners.any? { |owner| owner.id == listener.id }

    # `can_download` opens the curated public library — the songs tied to no account — and
    # nothing more. Without the `owners.empty?` half, an account with `can_download` could
    # pull a song the player will not even show it, which contradicts Song.visible_to and the
    # "hearing in full and taking a copy share one rule" decision recorded above.
    owners.empty? && can_download?(listener)
  end

  # Taking a copy. The same rule as hearing it in full — see full_audio_for? — kept
  # under its own name because that is what the download endpoints are doing.
  def downloadable_by?(listener)
    full_audio_for?(listener)
  end

  # The audio a listener may hear, the waveform that describes it, and how long it is,
  # answered together so the three cannot drift apart.
  #
  # Drift is the whole reason: waveforms are per FILE, so pairing the master with the
  # preview's waveform would leave the scrubber describing a 30-second cut while the
  # full track plays. Choosing the file has to choose the waveform and the length with
  # it.
  #
  # The decision lives here rather than in SongPresenter so that the public serializer
  # and the public views never name the master at all — ZukePublicBoundaryTest is a
  # source-level guard over exactly those files.
  #
  # @param user [User, nil] the listener, or nil for an anonymous one
  # @return [Hash] :audio and :waveform are attachments, :seconds is a number
  def listening_source_for(user)
    if full_audio_for?(user) && audio_file.attached?
      { audio: audio_file, waveform: waveform_data, seconds: audio_file_seconds }
    else
      { audio: preview_audio, waveform: preview_waveform_data, seconds: preview_seconds }
    end
  end

  # The preview's real length, falling back to the 30s window when Active Storage has
  # not analysed it. The cut passes duration in as metadata, so the player never waits
  # on an analyser job to learn how long a file is.
  #
  # 0 when nothing is attached: there is no length to describe, and the caller is a song
  # that `playable?` already excludes.
  def preview_seconds
    return 0 unless preview_audio.attached?

    attachment_seconds(preview_audio) || Zuke::PreviewCutter::PREVIEW_SECONDS
  end

  # The master's length, or 0 when Active Storage has not analysed it — the player
  # already handles a zero duration by using raw peaks without resampling.
  def audio_file_seconds
    attachment_seconds(audio_file) || 0
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
    :users,
    { image_attachment: :blob },
    { preview_audio_attachment: :blob },
    { preview_waveform_data_attachment: :blob },
    { banner_video_attachment: :blob }
  ].freeze

  # The same list plus the master's own attachments, for a request where the caller may
  # be allowed to hear the full track.
  #
  # Kept separate from SERIALIZATION_INCLUDES so the public path's preloads stay
  # master-free — preloading the master there would paper over a leak instead of
  # surfacing one, which is what the comment above is protecting.
  FULL_AUDIO_INCLUDES = (
    SERIALIZATION_INCLUDES + [
      { audio_file_attachment: :blob },
      { waveform_data_attachment: :blob }
    ]
  ).freeze

  delegate :name, to: :artist, prefix: true
  delegate :title, to: :album, prefix: true

  # Anyone the host application calls a curator of this collection. Asked on the listener
  # rather than tested as a type, so this model does not need to know which class signs
  # administrators in — ZukeAuth owns that translation.
  def self.librarian?(listener)
    listener.respond_to?(:zuke_librarian?) && listener.zuke_librarian?
  end

  # The songs a listener may see at all: the public library — every song tied to no
  # account — plus the ones that are theirs. A librarian sees everything, because they
  # curate it. An anonymous visitor sees the public library and nothing else.
  #
  # Visibility lives here for the same reason full_audio_for? does: a song a listener
  # cannot see is a song they cannot hear, so the two questions belong together. Until
  # now only the main player asked it, while artists, albums, genres and playlists
  # selected songs directly — so one surface could hide a song that four others showed.
  def self.visible_to(listener)
    return all if librarian?(listener)

    public_songs = left_joins(:users).where(users: { id: nil })
    return public_songs unless listener.respond_to?(:song_ids)

    public_songs
      .or(left_joins(:users).where(users: { id: listener.id }))
      .distinct
  end

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

  # Whether this listener's account is flagged to pull from the curated library. Asked on the
  # listener, so the model needs no knowledge of which class the host application uses.
  def can_download?(listener)
    listener.respond_to?(:can_download?) && listener.can_download?
  end

  # The duration Active Storage analysed, or nil when it has not run yet. The preview
  # and the master read it the same way; only the fallback differs.
  def attachment_seconds(attachment)
    return nil unless attachment.attached?

    attachment.metadata["duration"]
  end

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
