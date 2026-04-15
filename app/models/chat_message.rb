class ChatMessage < ApplicationRecord
  belongs_to :chat_session

  validates :role, presence: true, inclusion: { in: %w[user assistant] }
  validates :content, presence: true

  scope :ordered, -> { order(created_at: :asc) }

  ROLES = %w[user assistant].freeze
end
