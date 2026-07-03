module CarUs
  class OnboardingController < CarUs::BaseController
    before_action :authenticate_car_owner!
    before_action :require_onboarding

    CannedQuestions = [
      "Tell me about your car. How long have you had it? What's held up well — and what's falling apart?",
      "What's a typical week look like for you and this car? Commute? Errands? Road trips?",
      "If your car had a voice, what kind of personality would it have? Laid-back? Reliable? A little dramatic?"
    ].freeze

    def processing
      @vehicle = current_car_owner.vehicles.order(created_at: :desc).first
    end

    def chat
      @vehicle = current_car_owner.vehicles.order(created_at: :desc).first
      all_messages = current_car_owner.onboarding_messages || []

      answered = all_messages.count { |m| m["role"] == "owner" }
      q_from_param = (params[:q] || 0).to_i
      @question_index = [ q_from_param, answered ].max

      @question = CannedQuestions[@question_index]

      if @question.nil?
        current_car_owner.update!(onboarding_completed: true, onboarding_step: "complete")
        redirect_to carus_welcome_path and return
      end

      @messages = all_messages.map { |m| m.symbolize_keys }
    end

    def message
      @vehicle = current_car_owner.vehicles.order(created_at: :desc).first
      question_index = params[:question_index].to_i
      owner_reply = params[:message].to_s.strip
      return redirect_to onboarding_chat_path(q: question_index) if owner_reply.blank?

      # Save owner message immediately
      messages = current_car_owner.onboarding_messages || []
      messages << { "role" => "owner", "content" => owner_reply }
      current_car_owner.update!(onboarding_messages: messages)

      # Fire AI in background thread
      question = CannedQuestions[question_index]
      car_owner_id = current_car_owner.id
      history = messages.map { |m| m.symbolize_keys }

      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          owner = CarOwner.find(car_owner_id)
          msgs = owner.onboarding_messages || []

          reply = OnboardingChatService.respond(
            car_owner: owner,
            vehicle: owner.vehicles.order(created_at: :desc).first,
            question: question,
            owner_reply: owner_reply,
            conversation_history: history
          )

          msgs << { "role" => "assistant", "content" => reply }
          owner.update!(onboarding_messages: msgs)
        end
      end

      redirect_to onboarding_waiting_path(q: question_index + 1)
    end

    def waiting
      @vehicle = current_car_owner.vehicles.order(created_at: :desc).first
      next_index = (params[:q] || 1).to_i

      # Check if AI response is ready
      messages = current_car_owner.onboarding_messages || []
      owner_count = messages.count { |m| m["role"] == "owner" }
      assistant_count = messages.count { |m| m["role"] == "assistant" }

      if assistant_count >= owner_count && owner_count > 0
        # AI is done — redirect to next question
        if CannedQuestions[next_index].nil?
          current_car_owner.update!(onboarding_completed: true, onboarding_step: "complete")
          redirect_to carus_welcome_path and return
        else
          redirect_to onboarding_chat_path(q: next_index) and return
        end
      end

      # Still waiting — show loading, auto-refresh
      @next_q = next_index
    end

    private

    def require_onboarding
      return if current_car_owner.onboarding_completed != true
      redirect_to vehicles_path
    end
  end
end
