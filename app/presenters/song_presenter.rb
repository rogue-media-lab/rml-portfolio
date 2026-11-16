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
    {
      id: @song.id,
      # The PREVIEW, never audio_file. This hash is rendered on public surfaces,
      # and the preview is the only audio the public surface may emit; the full
      # track stays behind the admin. See Song.playable.
      url: @song.preview_audio.attached? ? @song.preview_audio.url : nil,
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
      # The preview's own waveform, so the scrubber describes the file that is
      # actually playing. Not the full track's.
      waveformUrl: proxy_url_for_blob(@song.preview_waveform_data),
      duration: preview_duration
    }
  end

  private

  # The preview's real length, falling back to the 30s window when Active Storage
  # has not analysed it. The player should never wait on an analyser job to learn
  # how long a file is, which is why the cut passes duration in as metadata.
  def preview_duration
    return 0 unless @song.preview_audio.attached?

    @song.preview_audio.metadata["duration"] || Zuke::PreviewCutter::PREVIEW_SECONDS
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
