# frozen_string_literal: true

# The SongPresenter class is responsible for formatting a Song object into a
# hash suitable for the Zuke music player. It centralizes the logic for
# generating attribute hashes, including URLs for attached assets, making the
# controllers cleaner and more maintainable.
class SongPresenter
  include Rails.application.routes.url_helpers

  def initialize(song)
    @song = song
  end

  def to_song_hash
    # Audio needs a direct URL for the player. We append a timestamp to force
    # the browser to treat this as a fresh request, bypassing any cached
    # responses that might be missing CORS headers.
    audio_url = @song.audio_file.attached? ? @song.audio_file.url : nil
    if audio_url
      separator = audio_url.include?("?") ? "&" : "?"
      audio_url = "#{audio_url}#{separator}t=#{Time.current.to_i}"
    end

    {
      id: @song.id,
      url: audio_url,
      title: @song.title,
      artist: @song.artist&.name,
      # Images can use the redirecting blob URL, which is stable
      banner: url_for_blob(@song.image),
      grid_banner: url_for_variant(@song.grid_image_variant),
      bannerMobile: url_for_variant(@song.mobile_image_variant),
      bannerVideo: url_for_blob(@song.banner_video),
      imageCredit: @song.image_credit,
      imageCreditUrl: @song.image_credit_url,
      imageLicense: @song.image_license,
      audioSource: @song.audio_source,
      audioLicense: @song.audio_license,
      additionalCredits: @song.additional_credits,
      waveformUrl: url_for_blob(@song.waveform_data),
      duration: @song.audio_file.attached? ? (@song.audio_file.metadata["duration"] || 0) : 0
    }
  end

  private

  # Generates a stable, redirecting URL for a blob.
  def url_for_blob(attachment)
    return nil unless attachment.attached?

    rails_blob_url(attachment)
  end

  # Generates a stable, redirecting URL for a processed variant.
  def url_for_variant(processed_variant)
    return nil unless processed_variant

    rails_blob_url(processed_variant)
  end
end
