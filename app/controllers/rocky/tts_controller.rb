# frozen_string_literal: true

module Rocky
  class TtsController < BaseController
    def synthesize
      text = params[:text].to_s.strip
      return head(:unprocessable_entity) if text.blank?
      return head(:unprocessable_entity) if text.length > 5000

      result = Rocky::TtsService.new(text: text).call

      send_data result[:audio_data],
                type: result[:content_type],
                disposition: "inline",
                filename: "rocky_tts.mp3"

    rescue Rocky::TtsService::Error => e
      Rails.logger.error("Rocky TTS error: #{e.message}")
      render json: { error: "TTS unavailable" }, status: :service_unavailable
    end
  end
end
