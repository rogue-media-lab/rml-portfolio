# frozen_string_literal: true

class RockyController < ApplicationController
  include ActionController::Live

  allow_browser versions: :modern

  # GET /rocky/chat — turbo frame: render the Rocky interface
  def chat
    @session = find_or_build_session
    @messages = @session ? @session.chat_messages.ordered : []
    @prompt_count = session[:rocky_prompts] || 0
    @anon_limit = ROCKY_ANON_LIMIT
    @logged_in = user_signed_in?

    render :chat, formats: :html, layout: false
  end

  # POST /rocky/messages — SSE streaming chat
  def create
    content = params[:content].to_s.strip
    return head(:unprocessable_entity) if content.blank?

    # Rate limit anonymous users
    @prompt_count = (session[:rocky_prompts] || 0)
    unless user_signed_in?
      if @prompt_count >= ROCKY_ANON_LIMIT
        render json: { error: "limit_reached", message: "You've used all #{ROCKY_ANON_LIMIT} free prompts. Sign in to continue chatting with Rocky." }, status: :forbidden
        return
      end
      session[:rocky_prompts] = @prompt_count + 1
    end

    # Build message history
    chat_session = find_or_build_session
    messages = []

    if chat_session
      # Persisted session (logged in)
      chat_session.chat_messages.create!(role: "user", content: content)
      messages = chat_session.chat_messages.ordered.map { |m| { role: m.role, content: m.content } }
    else
      # Anonymous — use session-stored messages
      session[:rocky_messages] ||= []
      session[:rocky_messages] << { role: "user", content: content }
      messages = session[:rocky_messages].dup
    end

    # SSE streaming
    response.headers["Content-Type"] = "text/event-stream"
    response.headers["Cache-Control"] = "no-cache"
    response.headers["X-Accel-Buffering"] = "no"

    assistant_text = ""

    begin
      service = Rocky::ChatService.new(messages: messages)
      assistant_text = service.stream do |chunk|
        response.stream.write("data: #{chunk.to_json}\n\n")
      end

      # Persist or store assistant response
      if chat_session
        chat_session.chat_messages.create!(role: "assistant", content: assistant_text)
      else
        session[:rocky_messages] << { role: "assistant", content: assistant_text }
      end

    rescue => e
      Rails.logger.error("Rocky chat error: #{e.message}")
      response.stream.write("data: {\"type\":\"error\",\"message\":\"Rocky is having trouble. Try again.\"}\n\n")
    ensure
      response.stream.close
    end
  end

  # POST /rocky/tts — synthesize speech
  def tts
    text = params[:text].to_s.strip
    return head(:unprocessable_entity) if text.blank?
    return head(:unprocessable_entity) if text.length > 5000

    result = Rocky::TtsService.new(text: text).call

    send_data result[:audio_data],
              type: result[:content_type],
              disposition: "inline",
              filename: "rocky_tts.mp3"
  rescue Rocky::TtsService::Error => e
    Rails.logger.error("Rocky TTS error: #{e.message}")
    render json: { error: "TTS unavailable" }, status: :service_unavailable
  end

  # GET /rocky/tone?description=... — match and serve tone audio
  def tone
    description = params[:description].to_s.strip
    return head(:bad_request) if description.blank?

    tone_path = Rocky::ToneService.match(description)

    if tone_path
      full_path = Rails.root.join("public", tone_path.delete_prefix("/"))
      if File.exist?(full_path)
        send_file full_path, type: "audio/mpeg", disposition: "inline"
      else
        head :not_found
      end
    else
      head :not_found
    end
  end

  private

  def find_or_build_session
    return nil unless user_signed_in?

    if params[:session_id].present?
      current_user.chat_sessions.find_by(id: params[:session_id])
    else
      current_user.chat_sessions.order(created_at: :desc).first ||
        current_user.chat_sessions.create!
    end
  end
end
