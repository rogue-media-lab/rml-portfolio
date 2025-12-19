require "google/apis/youtube_v3"

# Fetches and processes videos from a hermit's YouTube channel.
class YoutubeService
  def initialize(hermit)
    @hermit = hermit
    @youtube = Google::Apis::YoutubeV3::YouTubeService.new
    @youtube.key = Rails.application.credentials.dig(:youtube, :api_key)
  end

  def fetch_videos
    handle = @hermit.youtube.strip
    uploads_playlist_id = get_uploads_playlist_id(handle)
    return unless uploads_playlist_id

    videos = get_videos_from_playlist(uploads_playlist_id)
    videos.each do |video|
      save_video(video)
    end
  end

  private

  def get_uploads_playlist_id(handle)
    # First, search for the channel by its handle to get the channel ID
    search_response = @youtube.list_searches("snippet", q: handle, type: "channel", max_results: 1)
    channel_id = search_response.items.first&.id&.channel_id
    return nil unless channel_id

    # Then, use the channel ID to get the uploads playlist ID
    channel_response = @youtube.list_channels("contentDetails", id: channel_id)
    channel_response.items.first&.content_details&.related_playlists&.uploads
  rescue Google::Apis::ClientError => e
    Rails.logger.error "YouTube API error while fetching channel details: #{e.message}"
    nil
  end

  def get_videos_from_playlist(playlist_id)
    videos = []
    next_page_token = nil
    loop do
      response = @youtube.list_playlist_items("snippet", playlist_id: playlist_id, max_results: 50, page_token: next_page_token)
      videos.concat(response.items)
      next_page_token = response.next_page_token
      break unless next_page_token
    end
    videos
  rescue Google::Apis::ClientError => e
    Rails.logger.error "YouTube API error while fetching playlist items: #{e.message}"
    []
  end

  def save_video(video)
    video_id = video.snippet.resource_id.video_id
    existing_video = @hermit.hermit_videos.find_by(youtube_video_id: video_id)
    return if existing_video

    title = video.snippet.title
    season, episode = extract_season_and_episode(title)

    @hermit.hermit_videos.create(
      youtube_video_id: video_id,
      thumbnail_url: video.snippet.thumbnails.high.url,
      title: title,
      season: season,
      episode: episode
    )
  end

  def extract_season_and_episode(title)
    # This is a simple regex, it might need to be adjusted based on the video title format
    match = title.match(/Season (\d+).*Episode (\d+)/i)
    return [ nil, nil ] unless match

    [ match[1].to_i, match[2].to_i ]
  end
end
