require "test_helper"
require "minitest/mock"

class SoundCloudSongPresenterTest < ActiveSupport::TestCase
  setup do
    @track_data = {
      "id" => 12345,
      "title" => "SoundCloud Track",
      "user" => { "username" => "ArtistUser" },
      "artwork_url" => "https://i1.sndcdn.com/artworks-large.jpg",
      "license" => "cc-by",
      "waveform_url" => "https://w1.sndcdn.com/waveform.png",
      "duration" => 60000,
      "track_authorization" => "auth_token",
      "media" => {
        "transcodings" => [
          {
            "format" => { "protocol" => "hls", "mime_type" => "audio/mpeg" },
            "url" => "https://api.soundcloud.com/hls/123"
          }
        ]
      }
    }
  end

  test "to_song_hash formats track data correctly" do
    # We need to stub the network call inside stream_url method
    # Since stream_url is private and called by to_song_hash, we can stub Net::HTTP

    mock_response = Minitest::Mock.new
    mock_response.expect :is_a?, true, [ Net::HTTPSuccess ]
    mock_response.expect :body, '{"url": "https://final.stream.url/playlist.m3u8"}'

    Net::HTTP.stub :get_response, mock_response do
      presenter = SoundCloudSongPresenter.new(@track_data)
      hash = presenter.to_song_hash

      assert_equal "soundcloud-12345", hash[:id]
      assert_equal "SoundCloud Track", hash[:title]
      assert_equal "ArtistUser", hash[:artist]
      assert_equal "https://final.stream.url/playlist.m3u8", hash[:url]
      assert_equal "https://i1.sndcdn.com/artworks-t500x500.jpg", hash[:banner]
      assert_equal 60.0, hash[:duration]
      assert_equal "SoundCloud", hash[:audioSource]
    end

    mock_response.verify
  end

  test "to_song_hash handles missing stream url gracefully" do
    # Remove transcodings to simulate no stream available
    @track_data["media"] = nil

    presenter = SoundCloudSongPresenter.new(@track_data)
    hash = presenter.to_song_hash

    assert_nil hash[:url]
  end
end
