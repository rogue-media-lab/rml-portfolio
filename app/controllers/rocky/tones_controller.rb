# frozen_string_literal: true

module Rocky
  class TonesController < BaseController
    def match
      description = params[:description].to_s.strip
      return head(:bad_request) if description.blank?

      tone = Rocky::ToneMatcherService.match(description)

      if tone&.audio_file&.attached?
        send_data tone.audio_file.download,
                  type: tone.audio_file.content_type.presence || "audio/mpeg",
                  disposition: "inline"
      else
        head :not_found
      end
    end
  end
end
