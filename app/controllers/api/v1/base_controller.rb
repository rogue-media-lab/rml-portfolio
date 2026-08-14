# frozen_string_literal: true

# Base controller for all API v1 endpoints.
# Uses ActionController::API for lightweight JSON-only responses
# (no layout, no cookies, no session) and bearer-token auth.
module Api
  module V1
    class BaseController < ActionController::API
      include ApiAuth

      rescue_from ActionController::ParameterMissing, with: :render_parameter_missing
      rescue_from ActiveRecord::RecordInvalid, with: :render_record_invalid

      private

      def render_parameter_missing(error)
        render json: { errors: { base: [ error.message ] } }, status: :unprocessable_entity
      end

      def render_record_invalid(error)
        render json: { errors: error.record&.errors || { base: [ error.message ] } },
               status: :unprocessable_entity
      end
    end
  end
end
