# frozen_string_literal: true

# The SongPresenter class is responsible for formatting a Song object into a
# hash suitable for the Zuke music player. It centralizes the logic for
# generating attribute hashes, including URLs for attached assets, making the
# controllers cleaner and more maintainable.
class SongPresenter
  include Rails.application.routes.url_helpers

  # How long a listener's audio URL stays valid, where the storage service honours it.
  # Comfortably longer than any track, so a URL cannot lapse mid-playback.
  AUDIO_URL_TTL = 10.minutes

  def initialize(song, listener: nil)
    @song = song
    @listener = listener
  end

  def to_song_hash
    # What this listener may hear, decided in one place by Song#listening_source_for:
    # the preview for anyone anonymous or unentitled, the full track for a listener the
    # song's own rule allows. Audio, waveform and length come back together, so the
    # scrubber always describes the file that is actually playing.
    source = @song.listening_source_for(@listener)

    {
      id: @song.id,
      url: audio_url(source[:audio]),
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
      waveformUrl: proxy_url_for_blob(source[:waveform]),
      duration: source[:seconds]
    }
  end

  private

  # Explicitly time-boxed where the storage service honours it. A PUBLIC S3 bucket does
  # not: Active Storage returns the public URL with no signature and ignores the expiry,
  # so until the service is private this asks for something the bucket does not enforce.
  # The gate that actually matters is who is handed a URL at all — see
  # Song#full_audio_for?.
  def audio_url(attachment)
    return nil unless attachment.attached?

    attachment.url(expires_in: AUDIO_URL_TTL)
  end

  # Generates a stable, redirecting URL for a blob.
  def url_for_blob(attachment)
    return nil unless attachment.attached?

    rails_blob_url(attachment)
  end

  # Generates a proxy URL for a blob to avoid CORS issues with fetch().
  def proxy_url_for_blob(attachment)
    return nil unless attachment.attached?

    rails_storage_proxy_url(attachment)
  end

  # Generates a stable, redirecting URL for a processed variant.
  def url_for_variant(processed_variant)
    return nil unless processed_variant

    rails_blob_url(processed_variant)
  end
end
