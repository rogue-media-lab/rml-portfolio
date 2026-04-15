class ChatSession < ApplicationRecord
  belongs_to :user
  has_many :chat_messages, dependent: :destroy

  validates :user, presence: true

  after_create :set_default_title

  private

  def set_default_title
    update_column(:title, "Session #{id}") if title.blank?
  end
end
