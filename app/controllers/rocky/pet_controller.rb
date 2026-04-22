# frozen_string_literal: true

module Rocky
  class PetController < BaseController
    def hatch
      pet = current_user.rock_pet!

      if pet.hatch!
        redirect_to rocky_path, notice: "🎉 Your Rocky has hatched!"
      else
        redirect_to rocky_path, alert: "Your Rocky isn't ready to hatch yet. Keep chatting!"
      end
    end
  end
end