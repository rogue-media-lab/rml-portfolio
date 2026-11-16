require "test_helper"

# The delete endpoint. Its reason to exist is the reuse case: the API has no
# update, so a row that went live with no preview or wrong credits is fixed by
# deleting it and re-POSTing it.
class Api::V1::SongsDestroyTest < ActionDispatch::IntegrationTest
  TOKEN = "test_api_token_secret_hex_64_chars_long_enough_for_comparison_xxxx"
  WAVEFORM_JSON = '{"version":2,"channels":1,"data":[0,128,255]}'

  # Deliberately the test's own list, so "covers every attachment the model has"
  # below can prove it has not fallen behind the model.
  ATTACHMENT_NAMES = %i[
    image banner_video audio_file preview_audio waveform_data preview_waveform_data
  ].freeze

  setup do
    ENV["ZUKE_API_TOKEN"] = TOKEN
    @song = Song.create!(title: "Stacking Blocks", artist: Artist.create!(name: "Mason Roberts"))

    attach_file(@song, :audio_file, "audio.mp3", "audio/mpeg")
    attach_file(@song, :preview_audio, "audio.mp3", "audio/mpeg")
    attach_file(@song, :image, "cover.jpg", "image/jpeg")
    attach_file(@song, :banner_video, "banner.mp4", "video/mp4")
    attach_bytes(@song, :waveform_data, WAVEFORM_JSON)
    attach_bytes(@song, :preview_waveform_data, WAVEFORM_JSON)

    @song.reload
    @blob_ids = ATTACHMENT_NAMES.to_h { |name| [ name, @song.public_send(name).blob.id ] }
  end

  teardown do
    ENV.delete("ZUKE_API_TOKEN")
  end

  # Adding an attachment to Song must fail here until it is covered, or a delete
  # would skip purging it and no caller would ever see what was left behind.
  test "covers every attachment the model has" do
    assert_equal Song.attachment_reflections.keys.sort.map(&:to_sym), ATTACHMENT_NAMES.sort,
      "Song has an attachment this test does not exercise"
  end

  test "requires a token" do
    delete api_v1_song_url(@song)
    assert_response :unauthorized
  end

  test "returns 404 for an id that is not there, and deletes nothing" do
    assert_no_difference("Song.count") do
      delete api_v1_song_url(999_999), headers: auth_headers
    end

    assert_response :not_found
    assert_equal "Not found", JSON.parse(response.body)["error"]
  end

  test "deletes the song and names what it removed" do
    id = @song.id

    assert_difference("Song.count", -1) do
      delete api_v1_song_url(id), headers: auth_headers
    end

    assert_response :ok
    body = JSON.parse(response.body)
    assert_equal id, body["id"]
    assert_equal "Stacking Blocks", body["title"]
    assert_equal "Mason Roberts", body["artist"]
    assert body["deleted"]
    assert_nil Song.find_by(id: id)
  end

  # The security guarantee. Rails destroys the attachment rows but only ENQUEUES
  # the blob purges — and a queued job dies with the dyno on the :async adapter.
  # No job runs in this test, so a master still in the bucket would still have its
  # blob row here, and would still be fetchable by anyone holding the URL.
  test "purges the master blob within the request, without waiting for a job" do
    delete api_v1_song_url(@song), headers: auth_headers

    assert_response :ok
    assert_nil ActiveStorage::Blob.find_by(id: @blob_ids[:audio_file]),
      "the master is still in the public bucket"
  end

  test "purges every attached file, not just the ones that were easy to attach" do
    delete api_v1_song_url(@song), headers: auth_headers

    assert_response :ok
    @blob_ids.each do |name, id|
      assert_nil ActiveStorage::Blob.find_by(id: id), "#{name} was left behind"
    end
    assert_equal ATTACHMENT_NAMES.size, JSON.parse(response.body)["purged_files"]
  end

  # The HIGH from review, pinned as an order rather than as a simulated failure:
  # a purge has to run while the row that names the blobs still exists. Destroying
  # first commits the deletion, so a purge that then failed would orphan the master
  # in a public-read bucket with the only record that could reach it already gone —
  # and the caller's retry would answer 404 for ever.
  test "purges while the song still exists, so a failed purge stays retryable" do
    song = @song
    row_present = []

    ActiveStorage::Blob.class_eval do
      unless method_defined?(:purge_without_observation)
        alias_method :purge_without_observation, :purge
      end

      define_method(:purge) do
        row_present << Song.exists?(song.id)
        purge_without_observation
      end
    end

    begin
      delete api_v1_song_url(song), headers: auth_headers
    ensure
      ActiveStorage::Blob.class_eval { alias_method :purge, :purge_without_observation }
    end

    assert_response :ok
    assert_equal ATTACHMENT_NAMES.size, row_present.size, "expected every attachment to be purged"
    assert row_present.all?,
      "the song was already destroyed when a purge ran — a failed purge would be unrecoverable"
  end

  test "leaves its playlists rather than leaving them pointing at a ghost" do
    playlist = Playlist.create!(name: "Mix")
    playlist.songs << @song
    assert playlist.reload.songs.include?(@song), "setup: the song should be on the playlist"

    assert_difference("PlaylistSong.count", -1) do
      delete api_v1_song_url(@song), headers: auth_headers
    end

    assert_response :ok
    assert_empty playlist.reload.songs
  end

  test "drops the song from the public playable set" do
    id = @song.id
    assert Song.playable.exists?(id), "setup: a song with a preview should be playable"

    delete api_v1_song_url(id), headers: auth_headers

    assert_not Song.playable.exists?(id)
  end

  private

  def auth_headers
    { "Authorization" => "Bearer #{TOKEN}" }
  end

  # Reads the bytes instead of handing over an open handle. File.open with no
  # block leaks a descriptor per call — the same leak fixed in GenerateWaveformJob.
  def attach_file(song, name, fixture, content_type)
    bytes = File.binread(Rails.root.join("test/fixtures/files", fixture))
    attach_bytes(song, name, bytes, content_type, filename: fixture)
  end

  def attach_bytes(song, name, bytes, content_type = "application/json", filename: nil)
    song.public_send(name).attach(
      io: StringIO.new(bytes),
      filename: filename || "#{name}.json",
      content_type: content_type
    )
  end
end
