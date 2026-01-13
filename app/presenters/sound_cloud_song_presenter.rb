# frozen_string_literal: true

# Takes a raw SoundCloud track object from the API and formats it
# into the standard song object that the Zuke player expects.
class SoundCloudSongPresenter
  def initialize(track_data)
    @track = track_data
  end

  def to_song_hash
    # Check for custom artwork first
    custom_artwork = CustomSoundCloudArtwork.find_by(soundcloud_track_id: @track['id'].to_s)

    if custom_artwork&.custom_image&.attached?
      # Use custom artwork
      banner = custom_artwork.full_image_url
      grid_banner = custom_artwork.grid_image_url
    else
      # Fall back to SoundCloud artwork
      artwork_url = @track["artwork_url"]
      banner = artwork_url&.gsub("large", "t500x500")
      grid_banner = artwork_url&.gsub("large", "t300x300")
    end

    {
      id: "soundcloud-#{@track['id']}",
      url: stream_url,
      title: @track["title"],
      artist: @track.dig("user", "username"),
      banner: banner,
      grid_banner: grid_banner,
      bannerMobile: banner, # Use same image for mobile
      bannerVideo: nil,  # No video component for SoundCloud tracks
      imageCredit: nil,
      imageCreditUrl: nil,
      imageLicense: nil,
      audioSource: "SoundCloud",
      audioLicense: @track["license"],
      additionalCredits: nil,
      waveformUrl: @track["waveform_url"],
      duration: @track["duration"] ? @track["duration"] / 1000.0 : 0
    }
  end

  private

  # Finds the first available HLS stream URL by performing a two-step fetch.
  # 1. Get the URL to a JSON object containing the real stream URL.
  # 2. Fetch and parse that JSON object to return the final stream URL.
  #
  # @return [String, nil] The final HLS stream URL.
  def stream_url
    # Step 1: Find the initial API endpoint URL from the track data.
    return nil unless @track.dig("media", "transcodings")
    hls_streams = @track["media"]["transcodings"].select { |t| t.dig("format", "protocol") == "hls" }
    return nil if hls_streams.empty?
    stream_info = hls_streams.find { |s| s.dig("format", "mime_type")&.include?("aac") } || hls_streams.first

    # This is the URL to the JSON object, not the stream itself.
    json_url = "#{stream_info['url']}?client_id=#{SoundCloudService::CLIENT_ID}&track_authorization=#{@track['track_authorization']}"

    # Step 2: Fetch the JSON and extract the final stream URL.
    begin
      uri = URI(json_url)
      response = Net::HTTP.get_response(uri)

      if response.is_a?(Net::HTTPSuccess)
        JSON.parse(response.body)["url"]
      else
        Rails.logger.error "SoundCloud Stream Fetch Error: #{response.code} #{response.message} for URL: #{json_url}"
        nil
      end
    rescue JSON::ParserError, URI::InvalidURIError => e
      Rails.logger.error "SoundCloud Stream Parse Error: #{e.message}"
      nil
    end
  end
end
