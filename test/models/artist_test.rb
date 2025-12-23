require "test_helper"

class ArtistTest < ActiveSupport::TestCase
  test "should be valid with valid attributes" do
    artist = Artist.new(name: "The Beatles")
    assert artist.valid?
  end

  test "should require a name" do
    artist = Artist.new(name: "")
    assert_not artist.valid?
    assert_includes artist.errors[:name], "can't be blank"
  end

  test "should have unique name" do
    Artist.create!(name: "The Beatles")
    duplicate_artist = Artist.new(name: "The Beatles")
    assert_not duplicate_artist.valid?
    assert_includes duplicate_artist.errors[:name], "has already been taken"
  end

  test "should have unique name case insensitive" do
    Artist.create!(name: "The Beatles")
    duplicate_artist = Artist.new(name: "the beatles")
    assert_not duplicate_artist.valid?
    assert_includes duplicate_artist.errors[:name], "has already been taken"
  end

  test "should destroy associated songs when destroyed" do
    artist = Artist.create!(name: "The Beatles")
    artist.songs.create!(title: "Hey Jude", audio_source: "test.mp3")

    assert_difference("Song.count", -1) do
      artist.destroy
    end
  end

  test "should destroy associated albums when destroyed" do
    artist = Artist.create!(name: "The Beatles")
    artist.albums.create!(title: "Abbey Road")

    assert_difference("Album.count", -1) do
      artist.destroy
    end
  end
end
