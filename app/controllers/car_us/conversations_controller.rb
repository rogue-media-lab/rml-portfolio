module CarUs
  class ConversationsController < CarUs::BaseController
    before_action :authenticate_technician!
    before_action :set_conversation, only: [ :show, :create_message ]
    layout "car_us/car_owner"

    def index
      @conversations = current_technician.conversations.active.includes(:vehicle)
    end

    def show
      @messages = @conversation.messages.order(:created_at)
    end

    def create
      @conversation = current_technician.conversations.create!(title: params[:title].presence)

      content = params[:content].presence || "New vehicle intake"

      # First message from tech
      message = @conversation.messages.create!(
        role: "tech",
        content: content
      )
      message.photo.attach(params[:photo]) if params[:photo].present?

      # If photo provided, ChatService handles VIN extraction natively.
      # If text-only, try to extract VIN from message content.
      process_intake(@conversation, message, params[:photo]) unless params[:photo].present?

      # AI response — pass photo for vision if present (use raw upload, not attachment)
      ai_reply = CarUs::ChatService.new(@conversation).respond_to(message, photo: params[:photo])
      ai_message = @conversation.messages.create!(role: "assistant", content: ai_reply)

      # If photo was used, try to extract VIN from the AI response and link vehicle
      link_vehicle_from_response(@conversation, ai_reply) if params[:photo].present? && @conversation.vehicle.blank?

      redirect_to conversation_path(@conversation)
    end

    def create_message
      message = @conversation.messages.create!(
        role: "tech",
        content: params[:content]
      )
      message.photo.attach(params[:photo]) if params[:photo].present?

      # Text-based VIN extraction fallback (only if no vehicle yet and no photo)
      process_intake(@conversation, message, params[:photo]) unless @conversation.vehicle || params[:photo].present?

      # AI response — pass photo for vision if present
      ai_reply = CarUs::ChatService.new(@conversation).respond_to(message, photo: params[:photo])
      ai_message = @conversation.messages.create!(role: "assistant", content: ai_reply)

      # Link vehicle from AI response if photo was used
      link_vehicle_from_response(@conversation, ai_reply) if params[:photo].present? && @conversation.vehicle.blank?

      @conversation.touch
      redirect_to conversation_path(@conversation)
    end

    private

    def set_conversation
      @conversation = current_technician.conversations.find(params[:id])
    end

    # Text-based VIN extraction — look for VIN pattern in message content.
    # Photo-based extraction is handled by ChatService directly.
    def process_intake(conversation, message, raw_photo = nil)
      vin = message.content.to_s.scan(/[A-HJ-NPR-Z0-9]{16,17}/).first
      return unless vin

      decoded = CarUs::Vehicle.decode_vin(vin)
      return unless decoded&.dig(:make).present?

      vehicle = CarUs::Vehicle.find_or_create_by!(vin: vin) do |v|
        v.year = decoded[:year]
        v.make = decoded[:make]
        v.model = decoded[:model]
        v.trim = decoded[:trim]
        v.engine_size = decoded[:engine_size]
        v.transmission = decoded[:transmission]
        v.last_lookup_at = Time.current
        v.looked_up_by = current_technician.id
      end

      conversation.update!(vehicle: vehicle, title: "#{vehicle.year} #{vehicle.make} #{vehicle.model}")

      # Always update looked_up_by even on existing vehicles
      vehicle.update!(last_lookup_at: Time.current, looked_up_by: current_technician.id)

      # AI enrichment
      enriched = CarUs::AiEnrichmentService.new(
        vin: vin, decoded: decoded, notes: message.content.to_s
      ).enrich

      if enriched.present?
        specs = enriched["specs"] || {}
        vehicle.update!(
          ai_specs: specs.to_json,
          ai_suggestions: enriched["service_suggestions"]&.to_json,
          ai_plain_english: enriched["plain_english"],
          ai_difficulty_notes: enriched["difficulty_notes"]
        )
      end
    end

    # After ChatService responds with vision, try to extract VIN from the response.
    # Parse the AI response for a VIN pattern and link/create the vehicle.
    def link_vehicle_from_response(conversation, ai_response)
      vin = ai_response.to_s.scan(/[A-HJ-NPR-Z0-9]{16,17}/).first
      return unless vin

      decoded = CarUs::Vehicle.decode_vin(vin)
      return unless decoded&.dig(:make).present?

      vehicle = CarUs::Vehicle.find_or_create_by!(vin: vin) do |v|
        v.year = decoded[:year]
        v.make = decoded[:make]
        v.model = decoded[:model]
        v.trim = decoded[:trim]
        v.engine_size = decoded[:engine_size]
        v.transmission = decoded[:transmission]
        v.last_lookup_at = Time.current
        v.looked_up_by = current_technician.id
      end

      conversation.update!(vehicle: vehicle, title: "#{vehicle.year} #{vehicle.make} #{vehicle.model}")

      # Always update looked_up_by even on existing vehicles
      vehicle.update!(last_lookup_at: Time.current, looked_up_by: current_technician.id)

      # AI enrichment — store specs on the vehicle record
      enriched = CarUs::AiEnrichmentService.new(
        vin: vin, decoded: decoded, notes: ""
      ).enrich

      if enriched.present?
        specs = enriched["specs"] || {}
        vehicle.update!(
          ai_specs: specs.to_json,
          ai_suggestions: enriched["service_suggestions"]&.to_json,
          ai_plain_english: enriched["plain_english"],
          ai_difficulty_notes: enriched["difficulty_notes"]
        )
      end
    end
  end
end
