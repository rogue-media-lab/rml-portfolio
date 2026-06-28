class MilkAdmin::CarusShopsController < ApplicationController
  before_action :authenticate_milk_admin!
  before_action :set_shop, only: [ :show, :edit, :update, :destroy ]

  def index
    @shops = CarUs::Shop.order(:name)
  end

  def show
    @technicians = @shop.technicians.order(:email)
    @car_owners = @shop.car_owners.order(created_at: :desc).limit(20)
    @flash_alerts = @shop.flash_alerts.order(created_at: :desc).limit(5)
    @services = @shop.services.order(:name)
  end

  def new
    @shop = CarUs::Shop.new
  end

  def create
    @shop = CarUs::Shop.new(shop_params)

    if @shop.save
      # Create technician account if credentials provided
      if technician_params[:email].present? && technician_params[:password].present?
        tech = @shop.technicians.create!(technician_params)
        flash[:notice] = "Shop created. Technician #{tech.email} can log in at /carus/technicians/sign_in"
      else
        flash[:notice] = "Shop created. No technician account — add one from the manager portal."
      end

      redirect_to milk_admin_carus_shop_path(@shop)
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @shop.update(shop_params)
      redirect_to milk_admin_carus_shop_path(@shop), notice: "Shop updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @shop.destroy
    redirect_to milk_admin_carus_shops_path, notice: "Shop deleted."
  end

  private

  def set_shop
    @shop = CarUs::Shop.find_by!(slug: params[:slug])
  end

  def shop_params
    params.require(:car_us_shop).permit(
      :name, :slug, :address, :phone, :email, :website, :description, :active
    )
  end

  def technician_params
    params.fetch(:technician, {}).permit(:email, :password, :password_confirmation)
  end
end