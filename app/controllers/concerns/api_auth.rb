# frozen_string_literal: true

# Provides bearer-token authentication for API controllers.
# The token is stored in Rails credentials under +:api_token+.
# Generate one with: rails runner "puts SecureRandom.hex(32)"
# Then add it: rails credentials:edit ->  api_token: <hex_string>
module ApiAuth
  extend ActiveSupport::Concern

  included do
    before_action :verify_api_token
  end

  private

  def verify_api_token
    provided = bearer_token.to_s
    expected = expected_token.to_s

    if expected.blank?
      render json: { error: "API token not configured" }, status: :internal_server_error
      return
    end

    unless ActiveSupport::SecurityUtils.secure_compare(provided, expected)
      render json: { error: "Unauthorized" }, status: :unauthorized
    end
  end

  def bearer_token
    pattern = /^Bearer\s+(.+)/i
    header = request.authorization.to_s
    header.match(pattern) { |match| match[1] } || params[:token].to_s
  end

  def expected_token
    Rails.application.credentials.api_token || ENV["ZUKE_API_TOKEN"]
  end
end
