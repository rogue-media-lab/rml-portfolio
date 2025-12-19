# Hermits Controller for Milk Admin
class MilkAdmin::HermitsController < ApplicationController
  before_action :authenticate_milk_admin!
  before_action :set_hermit, only: [ :edit, :update, :destroy ]

  def index
    redirect_to milk_admin_hermits_dashboard_path, status: :see_other
  end

  def dashboard
    @hermits = Hermit.all.order(:alias)
    render layout: false if turbo_frame_request?
  end

  def new
    @hermit = Hermit.new
    render layout: false if turbo_frame_request?
  end

  def edit
    render layout: false if turbo_frame_request?
  end

  def create
    @hermit = Hermit.new(hermit_params)

    respond_to do |format|
      if @hermit.save
        redirect_path = turbo_frame_request? ? milk_admin_hermits_dashboard_path : @hermit
        format.html { redirect_to redirect_path, notice: "Hermit was successfully created." }
        format.json { render :show, status: :created, location: @hermit }
      else
        format.html { render :new, status: :unprocessable_entity, layout: !turbo_frame_request? }
        format.json { render json: @hermit.errors, status: :unprocessable_entity }
      end
    end
  end

  def update
    respond_to do |format|
      if @hermit.update(hermit_params)
        redirect_path = turbo_frame_request? ? milk_admin_hermits_dashboard_path : @hermit
        format.html { redirect_to redirect_path, notice: "Hermit was successfully updated." }
        format.json { render :show, status: :ok, location: @hermit }
      else
        format.html { render :edit, status: :unprocessable_entity, layout: !turbo_frame_request? }
        format.json { render json: @hermit.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @hermit.destroy
    respond_to do |format|
      format.html { redirect_to milk_admin_hermits_dashboard_path, notice: "Hermit was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  private

  def set_hermit
    @hermit = Hermit.find(params[:id])
  end

  def hermit_params
    params.require(:hermit).permit(:first_name, :last_name, :alias, :alias_image_alt, :nick_name, :subs, :quote, :youtube, :twitch, :twitter, :instagram, :patreon, :skin_alt, :face_alt, :avatar_url, :banner_url, :alias_image_url)
  end
end
