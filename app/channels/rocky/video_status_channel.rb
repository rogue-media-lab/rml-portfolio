# frozen_string_literal: true

module Rocky
  class VideoStatusChannel < ApplicationCable::Channel
    def subscribed
      session_id = params[:chat_session_id].to_i
      # Verify the session belongs to the connected user
      session = current_user.chat_sessions.find_by(id: session_id)
      if session
        stream_from "rocky:video:#{session_id}"
      else
        reject
      end
    end

    def unsubscribed
      stop_all_streams
    end
  end
end
