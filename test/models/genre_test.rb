require "test_helper"

class GenreTest < ActiveSupport::TestCase
  test "should be valid with valid attributes" do
    genre = Genre.new(name: "Jazz")
    assert genre.valid?
  end

  test "should require a name" do
    genre = Genre.new(name: "")
    assert_not genre.valid?
    assert_includes genre.errors[:name], "can't be blank"
  end

  test "should have unique name" do
    # "Rock" is already in fixtures
    duplicate_genre = Genre.new(name: "Rock")
    assert_not duplicate_genre.valid?
    assert_includes duplicate_genre.errors[:name], "has already been taken"
  end

  test "should have unique name case insensitive" do
    # "Rock" is already in fixtures
    duplicate_genre = Genre.new(name: "rock")
    assert_not duplicate_genre.valid?
    assert_includes duplicate_genre.errors[:name], "has already been taken"
  end
end
