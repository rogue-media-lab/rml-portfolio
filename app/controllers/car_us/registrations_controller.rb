class CarUs::RegistrationsController < Devise::RegistrationsController
  layout "car_us/car_owner"

  before_action :configure_sign_up_params, only: [ :create ]

  protected

  def configure_sign_up_params
    devise_parameter_sanitizer.permit(:sign_up, keys: [ :shop_id, :first_name, :last_name ])
  end

  def after_sign_up_path_for(resource)
    new_vehicle_path
  end

  def after_sign_in_path_for(resource)
    vehicles_path
  end
end
