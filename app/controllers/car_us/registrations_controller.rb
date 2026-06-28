class CarUs::RegistrationsController < Devise::RegistrationsController
  layout "car_us/car_owner"

  protected

  def after_sign_up_path_for(resource)
    "/carus"
  end

  def after_sign_in_path_for(resource)
    coupons_path
  end
end