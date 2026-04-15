class Tone < ApplicationRecord
  has_one_attached :audio_file

  validates :name, presence: true, uniqueness: true

  def self.match(description)
    return nil if description.blank?

    # Try exact description match first
    found = where("LOWER(description) = ?", description.downcase.strip).first
    return found if found

    # Try any tag or word overlap
    words = description.downcase.split(/[\s,]+/).reject { |w| w.length < 3 }
    return nil if words.empty?

    where(
      words.map { "LOWER(description) LIKE ?" }.join(" OR "),
      *words.map { |w| "%#{w}%" }
    ).first
  end
end
