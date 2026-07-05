module CarUs
  class VehicleChatController < CarUs::BaseController
    before_action :authenticate_car_owner!
    before_action :set_vehicle

    def create
      content = params[:content].to_s.strip
      return head(:unprocessable_entity) if content.blank?

      messages = @vehicle.chat_messages || []

      # Save owner message
      messages << { "role" => "owner", "content" => content }
      @vehicle.update!(chat_messages: messages)

      # Build conversation history
      history = messages.map(&:deep_symbolize_keys)

      # Call AI
      reply = CarUs::GarageChatService.respond(
        vehicle: @vehicle,
        owner_message: content,
        conversation_history: history
      )

      # Save assistant response
      messages << { "role" => "assistant", "content" => reply }
      @vehicle.update!(chat_messages: messages)

      respond_to do |format|
        format.json { render json: { reply: reply, messages: messages } }
      end
    end

    private

    def set_vehicle
      @vehicle = current_car_owner.vehicles.find(params[:vehicle_id])
    end
  end
end
