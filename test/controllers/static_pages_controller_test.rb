require "test_helper"

class StaticPagesControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get root_url
    assert_response :success
  end

  # test "loads projects from fixtures and transforms them correctly" do
  # 1. Trigger the controller action (this will load fixtures and process them)
  # get root_url

  # 2. Get the transformed data from controller
  # projects = controller.view_assigns["small_projects"]

  # 3. Verify the results
  # assert_equal 2, projects.size, "Should load both fixtures"

  # Check first project transformation
  # salt_and_tar = projects.find { |p| p[:title] == "Salt and Tar" }
  # assert_not_nil salt_and_tar, "Should include Salt and Tar project"
  # assert_equal "This is an amazing project", salt_and_tar[:description]
  # assert_equal "/salt-and-tar", salt_and_tar[:path]

  # Check second project transformation
  # zuke = projects.find { |p| p[:title] == "Zuke" }
  # assert_not_nil zuke, "Should include Zuke project"
  # assert_equal "This is an amazing project", zuke[:description]
  # assert_equal "/zuke", zuke[:path]
  # end
end
