require "test_helper"

class AlbumTest < ActiveSupport::TestCase
  setup do
    @artist = Artist.create!(name: "Pink Floyd")
  end

  test "should be valid with valid attributes" do
    album = Album.new(title: "The Wall", artist: @artist)
    assert album.valid?
  end

  test "should require a title" do
    album = Album.new(title: "", artist: @artist)
    assert_not album.valid?
    assert_includes album.errors[:title], "can't be blank"
  end

  test "should require an artist" do
    album = Album.new(title: "The Wall", artist: nil)
    assert_not album.valid?
    assert_includes album.errors[:artist], "must exist"
  end

  test "should have unique title scoped to artist" do
    Album.create!(title: "The Wall", artist: @artist)
    duplicate_album = Album.new(title: "The Wall", artist: @artist)
    assert_not duplicate_album.valid?
    assert_includes duplicate_album.errors[:title], "has already been taken"
  end

  test "should allow same title for different artists" do
    Album.create!(title: "Greatest Hits", artist: @artist)
    other_artist = Artist.create!(name: "Queen")
    album = Album.new(title: "Greatest Hits", artist: other_artist)
    assert album.valid?
  end

  test "should destroy associated songs when destroyed" do
    album = Album.create!(title: "The Wall", artist: @artist)
    album.songs.create!(title: "Another Brick in the Wall", artist: @artist)

    assert_difference("Song.count", -1) do
      album.destroy
    end
  end
end
