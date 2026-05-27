# Hermit Crews Controller for Milk Admin
class MilkAdmin::HermitCrewsController < ApplicationController
  before_action :authenticate_milk_admin!
  before_action :set_hermit_crew, only: [ :edit, :update, :destroy ]

  def index
    redirect_to milk_admin_hermit_crews_dashboard_path, status: :see_other
  end

  def dashboard
    @hermit_crews = HermitCrew.includes(:hermits).order(:season, :name)
    render layout: false if turbo_frame_request?
  end

  def new
    @hermit_crew = HermitCrew.new
    @hermits = Hermit.order(:alias)
    render layout: false if turbo_frame_request?
  end

  def edit
    @hermits = Hermit.order(:alias)
    render layout: false if turbo_frame_request?
  end

  def create
    @hermit_crew = HermitCrew.new(hermit_crew_params)

    respond_to do |format|
      if @hermit_crew.save
        update_memberships
        redirect_path = turbo_frame_request? ? milk_admin_hermit_crews_dashboard_path : milk_admin_hermit_crews_path
        format.html { redirect_to redirect_path, notice: "Hermit crew was successfully created." }
      else
        @hermits = Hermit.order(:alias)
        format.html { render :new, status: :unprocessable_entity, layout: !turbo_frame_request? }
      end
    end
  end

  def update
    respond_to do |format|
      if @hermit_crew.update(hermit_crew_params)
        update_memberships
        redirect_path = turbo_frame_request? ? milk_admin_hermit_crews_dashboard_path : milk_admin_hermit_crews_path
        format.html { redirect_to redirect_path, notice: "Hermit crew was successfully updated." }
      else
        @hermits = Hermit.order(:alias)
        format.html { render :edit, status: :unprocessable_entity, layout: !turbo_frame_request? }
      end
    end
  end

  def destroy
    @hermit_crew.destroy
    respond_to do |format|
        format.html { redirect_to milk_admin_hermit_crews_dashboard_path, notice: "Hermit crew was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  private

  def set_hermit_crew
    @hermit_crew = HermitCrew.find_by!(slug: params[:id])
  end

  def hermit_crew_params
    params.require(:hermit_crew).permit(:name, :slug, :description, :image_url, :season)
  end

  def update_memberships
    return unless params[:hermit_crew][:hermit_ids]

    hermit_ids = params[:hermit_crew][:hermit_ids].reject(&:blank?).map(&:to_i)
    @hermit_crew.hermit_ids = hermit_ids
  end
end
