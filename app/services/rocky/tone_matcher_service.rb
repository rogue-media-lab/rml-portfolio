# frozen_string_literal: true

module Rocky
  class ToneMatcherService
    TONE_PATTERN = /\*🎵\s*(.*?)\s*🎵\*/

    # Extract all tone descriptions from text
    # Returns: [{ description: "curious, thoughtful chords", original: "*🎵 curious, thoughtful chords 🎵*" }]
    def self.extract(text)
      text.scan(TONE_PATTERN).map do |match|
        { description: match[0], original: "*🎵 #{match[0]} 🎵*" }
      end
    end

    # Remove tone markers from text for clean display
    def self.strip(text)
      text.gsub(TONE_PATTERN, "").gsub(/\n{3,}/, "\n\n").strip
    end

    # Find best matching Tone record for a description string
    # Returns Tone or nil
    def self.match(description)
      Tone.match(description)
    end

    # Returns the audio URL for a tone description, or nil
    def self.audio_url_for(description)
      tone = match(description)
      return nil unless tone&.audio_file&.attached?

      Rails.application.routes.url_helpers.rails_blob_path(tone.audio_file, only_path: true)
    end
  end
end
