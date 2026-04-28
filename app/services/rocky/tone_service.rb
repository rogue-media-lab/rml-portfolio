# frozen_string_literal: true

module Rocky
  class ToneService
    class << self
      # Match a tone description to an audio file path.
      # Returns the relative path to the tone file, or nil.
      def match(description)
        return nil if description.blank?

        index = load_index
        return nil if index.empty?

        # Exact match first
        exact = index[description.downcase.strip]
        return "/tones/#{exact}" if exact

        # Fuzzy: find the closest match by word overlap
        words = description.downcase.split(/[\s,]+/).reject { |w| w.length < 3 }
        return nil if words.empty?

        best_match = nil
        best_score = 0

        index.each do |desc, filename|
          desc_words = desc.downcase.split(/[\s,]+/)
          score = words.count { |w| desc_words.any? { |dw| dw.include?(w) || w.include?(dw) } }
          if score > best_score
            best_score = score
            best_match = filename
          end
        end

        best_score > 0 ? "/tones/#{best_match}" : nil
      end

      # Return all tone descriptions for the system prompt
      def descriptions
        load_index.keys.sort
      end

      private

      def load_index
        @index_cache ||= begin
          path = Rails.root.join("public", "tones", "tone_index.json")
          File.exist?(path) ? JSON.parse(File.read(path)) : {}
        rescue JSON::ParserError
          {}
        end
      end
    end
  end
end
