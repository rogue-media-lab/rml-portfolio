require "test_helper"

class MilkAdminControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  test "should get dashboard" do
    get root_url
    assert_response :success
  end

  # The admin had no route to the player. Signing in from the player sent them here, and on a
  # device with no address bar there was nothing to get back with — so this link and the
  # player's "Admin Dashboard" link are the two halves of the same door.
  test "the dashboard links to the music player" do
    sign_in milk_admins(:admin_one)

    get milk_admin_root_url
    assert_response :success
    assert_match(%r{/zuke/music}, response.body,
      "the admin needs a route to the player")
  end
end
