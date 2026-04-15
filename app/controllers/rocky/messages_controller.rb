# frozen_string_literal: true

module Rocky
  class MessagesController < BaseController
    include ActionController::Live

    protect_from_forgery with: :null_session, only: [:create]

    def create
      @chat_session = current_user.chat_sessions.find(params[:session_id])

      content = params[:content].to_s.strip
      return head(:unprocessable_entity) if content.blank?

      @chat_session.chat_messages.create!(role: "user", content: content)

      messages = @chat_session.chat_messages.ordered.map do |m|
        { role: m.role, content: m.content }
      end

      response.headers["Content-Type"]    = "text/event-stream"
      response.headers["Cache-Control"]   = "no-cache"
      response.headers["X-Accel-Buffering"] = "no"

      assistant_text = ""
      phase1_tool_calls = []
      phase1_usage = {}

      begin
        service = Rocky::ChatService.new(messages: messages)

        # ── Phase 1: Rocky's initial response ──────────────────────────────
        returned_tool_calls = service.stream do |chunk|
          case chunk[:type]
          when "content"
            assistant_text += chunk[:delta]
            sse_write(chunk)
          when "tool_call"
            phase1_tool_calls << chunk
            sse_write(chunk)
          when "phase_done"
            phase1_usage = chunk
          end
        end

        if returned_tool_calls.any?
          # ── Execute tool calls ────────────────────────────────────────────
          tool_results = []

          returned_tool_calls.each do |tc|
            result = execute_rocky_tool(tc[:name], tc[:input])

            if result
              if result[:pending]
                # Async video — job enqueued, placeholder message already created
                sse_write({ type: "video_pending", message_id: result[:message_id] })
                tool_results << {
                  tool_use_id: tc[:id],
                  content:     "Video is being generated in the background. Tell the user it is processing and will appear in the chat shortly."
                }
              else
                sse_write({ type: "media", media_type: result[:media_type], url: result[:url] })

                @chat_session.chat_messages.create!(
                  role:       "assistant",
                  content:    "[Generated #{result[:media_type]}]",
                  media_type: result[:media_type],
                  media_url:  result[:url]
                )

                tool_results << { tool_use_id: tc[:id], content: result[:url] }
              end
            else
              tool_results << { tool_use_id: tc[:id], content: "Generation failed." }
            end
          end

          # ── Phase 2: Rocky comments on the result ────────────────────────
          assistant_content_blocks = []
          assistant_content_blocks << { type: "text", text: assistant_text } if assistant_text.present?
          phase1_tool_calls.each do |tc|
            assistant_content_blocks << {
              type:  "tool_use",
              id:    tc[:tool_use_id],
              name:  tc[:tool],
              input: tc[:input]
            }
          end

          continuation_messages = messages + [
            { role: "assistant", content: assistant_content_blocks },
            { role: "user", content: tool_results.map { |tr|
              { type: "tool_result", tool_use_id: tr[:tool_use_id], content: tr[:content] }
            }}
          ]

          continuation_text = ""

          service.stream_continuation(messages: continuation_messages) do |chunk|
            case chunk[:type]
            when "content"
              continuation_text += chunk[:delta]
              sse_write(chunk)
            when "done"
              if continuation_text.present?
                @chat_session.chat_messages.create!(
                  role:          "assistant",
                  content:       continuation_text,
                  input_tokens:  chunk[:input_tokens] || 0,
                  output_tokens: chunk[:output_tokens] || 0,
                  cost_usd:      chunk[:cost_usd] || 0
                )
              end
              sse_write(chunk)
            end
          end

        else
          # ── No tool calls — save and close ────────────────────────────────
          message = @chat_session.chat_messages.create!(
            role:          "assistant",
            content:       assistant_text,
            input_tokens:  phase1_usage[:input_tokens] || 0,
            output_tokens: phase1_usage[:output_tokens] || 0,
            cost_usd:      phase1_usage[:cost_usd] || 0
          )

          sse_write({
            type:          "done",
            message_id:    message.id,
            input_tokens:  phase1_usage[:input_tokens] || 0,
            output_tokens: phase1_usage[:output_tokens] || 0,
            cost_usd:      phase1_usage[:cost_usd] || 0
          })
        end

      rescue => e
        Rails.logger.error("Rocky chat error: #{e.message}\n#{e.backtrace.first(5).join("\n")}")
        sse_write({ type: "error", message: "Rocky is having trouble. Try again." })
      ensure
        response.stream.close
      end
    end

    private

    def sse_write(data)
      response.stream.write("data: #{data.to_json}\n\n")
    end

    def execute_rocky_tool(tool_name, input)
      prompt = input["prompt"].to_s.strip
      return nil if prompt.blank?

      case tool_name
      when "generate_image"
        result = Rocky::ImageService.new(prompt: prompt).call
        { media_type: "image", url: result[:url] }
      when "generate_video"
        task_id = Rocky::VideoService.new(prompt: prompt).submit
        # Create placeholder message — job will update media_url when done
        placeholder = @chat_session.chat_messages.create!(
          role:       "assistant",
          content:    "[Video generating]",
          media_type: "video",
          media_url:  nil
        )
        Rocky::GenerateVideoJob.perform_later(
          task_id:         task_id,
          chat_message_id: placeholder.id,
          chat_session_id: @chat_session.id
        )
        { media_type: "video", url: nil, pending: true, message_id: placeholder.id }
      when "generate_music"
        result = Rocky::MusicService.new(prompt: prompt).call
        { media_type: "music", url: result[:url] }
      end
    rescue => e
      Rails.logger.error("Rocky tool execution failed (#{tool_name}): #{e.message}")
      nil
    end
  end
end
