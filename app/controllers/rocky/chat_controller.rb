# frozen_string_literal: true

module Rocky
  class ChatController < BaseController
    def index
      @session = current_user.chat_sessions.order(created_at: :desc).first
      @session ||= current_user.chat_sessions.create!
      @messages = @session.chat_messages.ordered
      @pet = current_user.rock_pet!
    end
  end
end
