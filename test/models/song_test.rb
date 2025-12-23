require "test_helper"

class SongTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @artist = Artist.create!(name: "Daft Punk")
    @album = Album.create!(title: "Discovery", artist: @artist)
  end

  test "should be valid with valid attributes" do
    song = Song.new(title: "One More Time", artist: @artist, album: @album)
    assert song.valid?
  end

  test "should create artist from nested attributes" do
    song = Song.new(title: "New Song")
    song.artist_attributes = { name: "New Artist" }

    assert song.save
    assert_equal "New Artist", song.artist.name
  end

  test "should reuse existing artist from nested attributes" do
    song = Song.new(title: "New Song")
    song.artist_attributes = { name: "Daft Punk" }

    assert song.save
    assert_equal @artist.id, song.artist.id
  end

  test "should create album from nested attributes" do
    song = Song.new(title: "Harder, Better, Faster, Stronger", artist: @artist)
    song.album_attributes = { title: "New Album" }

    assert song.save
    assert_equal "New Album", song.album.title
    assert_equal @artist.id, song.album.artist_id
  end

  test "should handle genre in nested album attributes" do
    song = Song.new(title: "Something About Us", artist: @artist)
    song.album_attributes = {
      title: "Discovery",
      genre: { name: "Electronic" }
    }

    assert song.save
    assert_equal "Electronic", song.album.genre.name
    assert_equal "Discovery", song.album.title
  end

  test "should schedule waveform generation when audio file attached" do
    song = Song.create!(title: "Aerodynamic", artist: @artist)

    assert_enqueued_with(job: GenerateWaveformJob) do
      song.audio_file.attach(
        io: File.open(Rails.root.join("test/fixtures/files/test_audio.mp3")),
        filename: "test_audio.mp3",
        content_type: "audio/mpeg"
      )
      song.save
    end
  end

  test "has_credits? returns true if any credit field present" do
    song = Song.new
    assert_not song.has_credits?

    song.image_credit = "Photographer"
    assert song.has_credits?
  end
end
