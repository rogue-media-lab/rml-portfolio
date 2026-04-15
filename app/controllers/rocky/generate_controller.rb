# frozen_string_literal: true

module Rocky
  class GenerateController < BaseController
    def image
      prompt = params[:prompt].to_s.strip
      return render json: { error: "Prompt required" }, status: :unprocessable_entity if prompt.blank?

      result = Rocky::ImageService.new(prompt: prompt).call
      render json: { url: result[:url], type: "image" }

    rescue Rocky::ImageService::Error => e
      render json: { error: e.message }, status: :service_unavailable
    end

    def video
      prompt     = params[:prompt].to_s.strip
      session_id = params[:session_id].to_i
      return render json: { error: "Prompt required" }, status: :unprocessable_entity if prompt.blank?

      chat_session = session_id > 0 ? current_user.chat_sessions.find_by(id: session_id) : nil

      task_id = Rocky::VideoService.new(prompt: prompt).submit

      if chat_session
        placeholder = chat_session.chat_messages.create!(
          role: "assistant", content: "[Video generating]", media_type: "video", media_url: nil
        )
        Rocky::GenerateVideoJob.perform_later(
          task_id:         task_id,
          chat_message_id: placeholder.id,
          chat_session_id: chat_session.id
        )
        render json: { pending: true, message_id: placeholder.id }
      else
        # No session — fall back to blocking poll (keeps old behavior if session_id missing)
        result = Rocky::VideoService.new(prompt: prompt).poll(task_id)
        render json: { url: result[:url], type: "video" }
      end

    rescue Rocky::VideoService::Error => e
      render json: { error: e.message }, status: :service_unavailable
    end

    def music
      prompt = params[:prompt].to_s.strip
      return render json: { error: "Prompt required" }, status: :unprocessable_entity if prompt.blank?

      result = Rocky::MusicService.new(prompt: prompt).call
      render json: { url: result[:url], type: "music" }

    rescue Rocky::MusicService::Error => e
      render json: { error: e.message }, status: :service_unavailable
    end
  end
end
