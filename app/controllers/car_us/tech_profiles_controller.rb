module CarUs
  class TechProfilesController < CarUs::BaseController
    before_action :authenticate_technician!
    layout "car_us/car_owner"

    def show
      jobs = current_technician.service_jobs
      @total_hours   = jobs.sum(:book_hours)
      @total_jobs    = jobs.count
      @open_jobs     = jobs.open.recent.includes(:vehicle)
      @weekly_hours  = jobs.this_week.completed.sum(:book_hours)
      @weekly_jobs   = jobs.this_week.completed.count
      @weekly_target = 40.0  # configurable per shop later
      @recent_jobs   = jobs.recent.includes(:vehicle)
    end

    def weekly_report
      jobs = current_technician.service_jobs.this_week.completed.order(completed_at: :desc).includes(:vehicle)
      @report = {
        completed: jobs,
        total_hours: jobs.sum(:book_hours),
        total_jobs: jobs.count,
        target: 40.0,
        week_start: Date.today.beginning_of_week(:saturday),
        week_end:   Date.today.end_of_week(:saturday),
        by_day: jobs.group_by { |j| j.completed_at&.to_date }
      }
    end
  end
end
