module CarUs
  class TechLookupsController < CarUs::BaseController
    before_action :authenticate_technician!
    layout "car_us/car_owner"

    def index
      @assigned_bookings = current_technician.assigned_bookings
        .where("preferred_date >= ?", Date.today)
        .order(preferred_date: :asc)
        .includes(vehicle: :car_owner)

      # Scope vehicles to this tech's shop, plus any vehicle looked up by this shop's techs
      shop_id = current_technician.shop_id
      shop_tech_ids = Technician.where(shop_id: shop_id).pluck(:id)
      shop_vehicles = CarUs::Vehicle
        .left_joins(:car_owner)
        .where(
          "car_owners.shop_id = :shop_id OR car_us_vehicles.looked_up_by IN (:tech_ids)",
          shop_id: shop_id, tech_ids: shop_tech_ids
        )

      # Apply search/filter params
      if params[:q].present?
        query = "%#{params[:q]}%"
        shop_vehicles = shop_vehicles.where(
          "car_us_vehicles.vin ILIKE :q OR car_us_vehicles.make ILIKE :q OR car_us_vehicles.model ILIKE :q OR CAST(car_us_vehicles.year AS text) ILIKE :q",
          q: query
        )
      end
      shop_vehicles = shop_vehicles.where(year: params[:year]) if params[:year].present?
      shop_vehicles = shop_vehicles.where(make: params[:make]) if params[:make].present?
      shop_vehicles = shop_vehicles.where(model: params[:model]) if params[:model].present?

      @vehicles = shop_vehicles.order(updated_at: :desc).limit(30)

      # Filter dropdowns — distinct values from this shop's vehicles
      @years  = shop_vehicles.distinct.order(year: :desc).pluck(:year).compact
      @makes  = shop_vehicles.distinct.order(:make).pluck(:make).compact
      @models = shop_vehicles.distinct.order(:model).pluck(:model).compact
    end

    def show
      @vehicle = CarUs::Vehicle.find(params[:id])
    end

    def new
      @vehicle = CarUs::Vehicle.new
    end

    def create
      @vehicle = CarUs::Vehicle.new(vehicle_params)

      if @vehicle.save
        redirect_to tech_lookup_path(@vehicle), notice: "Vehicle added."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def customer_lookup
      shop = current_technician.shop
      # Customers with their vehicles for this shop
      @customers = shop.car_owners.includes(:vehicles).order(created_at: :desc).limit(20)
      # Upcoming bookings due this week (for any tech at this shop)
      @due_this_week = CarUs::BookingRequest
        .joins(vehicle: :car_owner)
        .where(car_owners: { shop_id: shop.id })
        .where(preferred_date: Date.today..(Date.today + 7.days))
        .order(preferred_date: :asc)
        .includes(:technician, vehicle: :car_owner)
    end

    def update_specs
      @vehicle = CarUs::Vehicle.find(params[:id])
      specs = JSON.parse(@vehicle.ai_specs.presence || "{}") rescue {}
      specs.merge!(params.require(:specs).permit(
        :oil_weight, :oil_capacity_qts, :oil_filter, :drain_plug_torque_ft_lbs,
        :coolant_type, :transmission_fluid, :spark_plug,
        :tire_pressure_f, :tire_pressure_r
      ).to_h)
      @vehicle.update!(ai_specs: specs.to_json)
      redirect_to tech_lookup_path(@vehicle), notice: "Specs updated."
    end

    private

    def vehicle_params
      params.require(:car_us_vehicle).permit(:year, :make, :model, :vin, :mileage)
    end
  end
end
