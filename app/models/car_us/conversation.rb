class CarUs::Conversation < ApplicationRecord
  belongs_to :technician
  belongs_to :vehicle, class_name: "CarUs::Vehicle", optional: true
  has_many :messages, class_name: "CarUs::Message", dependent: :destroy

  scope :active, -> { where(active: true).order(updated_at: :desc) }

  def title_or_default
    title.presence || (vehicle ? "#{vehicle.year} #{vehicle.make} #{vehicle.model}" : "New Vehicle")
  end
end
