module CarUs
  class TechProfilesController < CarUs::BaseController
    before_action :authenticate_technician!
    layout "car_us/car_owner"

    def show
      @total_hours = current_technician.service_jobs.sum(:book_hours)
      @total_jobs = current_technician.service_jobs.count
      @recent_jobs = current_technician.service_jobs.recent.limit(5).includes(:vehicle)
    end
  end
end
