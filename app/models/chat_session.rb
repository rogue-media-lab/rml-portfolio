class ChatSession < ApplicationRecord
  belongs_to :user, optional: true
  has_many :chat_messages, dependent: :destroy

  after_create :set_default_title

  private

  def set_default_title
    update_column(:title, "Session #{id}") if title.blank?
  end
end
