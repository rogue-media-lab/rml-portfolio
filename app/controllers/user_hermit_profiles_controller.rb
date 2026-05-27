class UserHermitProfilesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_profile
  layout "hermit_plus"

  def show
  end

  def edit
  end

  def update
    if @profile.update(profile_params)
      redirect_to user_hermit_profile_path, notice: "Profile updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_profile
    @profile = current_user.user_hermit_profile || current_user.create_user_hermit_profile!
    @favorite_hermits = Hermit.order(:alias)
  end

  def profile_params
    params.require(:user_hermit_profile).permit(:favorite_hermit_id, :notifications_enabled)
  end
end
