class CarUs::Message < ApplicationRecord
  belongs_to :conversation, class_name: "CarUs::Conversation"
  has_one_attached :photo

  validates :role, presence: true
end
