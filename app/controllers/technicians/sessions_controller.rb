class Technicians::SessionsController < Devise::SessionsController
  layout "car_us/car_owner"

  protected

  def after_sign_in_path_for(resource)
    if resource.manager?
      manager_root_path
    else
      conversations_path
    end
  end
end
