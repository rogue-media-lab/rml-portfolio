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
      # Loading screen — give the AI a moment to analyze the photo and decode the VIN
      @vehicle = current_car_owner.vehicles.order(created_at: :desc).first
    end

    def chat
      @vehicle = current_car_owner.vehicles.order(created_at: :desc).first
      @question_index = (params[:q] || 0).to_i
      @question = CannedQuestions[@question_index]

      if @question.nil?
        # Chat complete — mark onboarding done
        current_car_owner.update!(onboarding_completed: true, onboarding_step: "complete")
        redirect_to carus_welcome_path and return
      end

      @messages = session[:onboarding_messages] || []
    end

    def message
      @vehicle = current_car_owner.vehicles.order(created_at: :desc).first
      question_index = params[:question_index].to_i
      owner_reply = params[:message].to_s.strip

      # Store messages in session
      session[:onboarding_messages] ||= []
      session[:onboarding_messages] << { role: "owner", content: owner_reply }

      # Build context for AI response
      question = CannedQuestions[question_index]

      # Get AI reply
      reply = OnboardingChatService.respond(
        car_owner: current_car_owner,
        vehicle: @vehicle,
        question: question,
        owner_reply: owner_reply,
        conversation_history: session[:onboarding_messages]
      )

      session[:onboarding_messages] << { role: "assistant", content: reply }

      # Move to next question
      next_index = question_index + 1

      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            "onboarding_chat",
            partial: "car_us/onboarding/chat_messages",
            locals: {
              messages: session[:onboarding_messages],
              question_index: next_index,
              next_question: CannedQuestions[next_index],
              vehicle: @vehicle
            }
          )
        end
        format.html { redirect_to onboarding_chat_path(q: next_index) }
      end
    end

    private

    def require_onboarding
      return if current_car_owner.onboarding_completed != true
      redirect_to vehicles_path
    end
  end
end
