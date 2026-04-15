# frozen_string_literal: true

module Rocky
  class GenerateVideoJob < ApplicationJob
    queue_as :default

    # Polls MiniMax for a pending video task, updates the ChatMessage record,
    # and broadcasts the result via ActionCable so the frontend can render inline.
    #
    # Arguments:
    #   task_id:         MiniMax task_id string returned from VideoService#submit
    #   chat_message_id: ID of the placeholder ChatMessage to update
    #   chat_session_id: ID of the ChatSession (for channel broadcast)
    def perform(task_id:, chat_message_id:, chat_session_id:)
      message = ChatMessage.find_by(id: chat_message_id)
      return unless message  # message deleted, nothing to do

      service = Rocky::VideoService.new
      result  = service.poll(task_id, max_attempts: 20, interval: 10)  # up to ~3 min 20 sec

      # Update the stored message with the real URL
      message.update!(media_url: result[:url])

      # Broadcast to the frontend
      ActionCable.server.broadcast(
        "rocky:video:#{chat_session_id}",
        {
          message_id: chat_message_id,
          url:        result[:url],
          status:     "ready"
        }
      )

    rescue Rocky::VideoService::Error => e
      Rails.logger.error("Rocky::GenerateVideoJob failed for task #{task_id}: #{e.message}")

      ActionCable.server.broadcast(
        "rocky:video:#{chat_session_id}",
        {
          message_id: chat_message_id,
          status:     "error",
          error:      "Video generation failed."
        }
      )
    end
  end
end
