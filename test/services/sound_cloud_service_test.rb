require "test_helper"
require "minitest/mock"

class SoundCloudServiceTest < ActiveSupport::TestCase
  setup do
    @service = SoundCloudService.new
  end

  test "search returns collection on success" do
    mock_response = Minitest::Mock.new
    mock_response.expect :is_a?, true, [ Net::HTTPSuccess ]
    mock_response.expect :body, '{"collection": [{"id": 1, "title": "Test Track"}]}'

    SoundCloudService.stub :access_token, "fake_token" do
      Net::HTTP.stub :get_response, mock_response do
        results = @service.search("query")
        assert_equal 1, results.length
        assert_equal "Test Track", results.first["title"]
      end
    end

    mock_response.verify
  end

  test "search returns empty array on failure" do
    mock_response = Minitest::Mock.new
    mock_response.expect :is_a?, false, [ Net::HTTPSuccess ]
    mock_response.expect :code, "500"
    mock_response.expect :message, "Internal Server Error"

    SoundCloudService.stub :access_token, "fake_token" do
      Net::HTTP.stub :get_response, mock_response do
        results = @service.search("query")
        assert_equal [], results
      end
    end

    mock_response.verify
  end

  test "get_track returns track data on success" do
    mock_response = Minitest::Mock.new
    mock_response.expect :is_a?, true, [ Net::HTTPSuccess ]
    mock_response.expect :body, '{"id": 123, "title": "Specific Track", "media": {}}'

    SoundCloudService.stub :access_token, "fake_token" do
      Net::HTTP.stub :get_response, mock_response do
        track = @service.get_track("123")
        assert_equal 123, track["id"]
        assert_equal "Specific Track", track["title"]
      end
    end

    mock_response.verify
  end

  test "get_track returns nil on failure" do
    mock_response = Minitest::Mock.new
    mock_response.expect :is_a?, false, [ Net::HTTPSuccess ]
    mock_response.expect :code, "404"
    mock_response.expect :message, "Not Found"

    # When V1 fails, it tries fallback
    # To keep it simple, we'll mock the fallback method too or just let it fail naturally
    @service.stub :get_v2_track_complete, nil do
      SoundCloudService.stub :access_token, "fake_token" do
        Net::HTTP.stub :get_response, mock_response do
          track = @service.get_track("999")
          assert_nil track
        end
      end
    end

    mock_response.verify
  end
end
