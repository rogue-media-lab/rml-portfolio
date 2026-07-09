module CarUs
  module Manager
    class ReportsController < BaseController
      def shop_weekly
        @week_start, @week_end = current_shop_week
        @jobs = current_shop_jobs_this_week
        @services = current_shop.services.active.order(:name)
        @service_counts = build_service_counts(@jobs, @services)
        @total_hours = @jobs.sum(:book_hours)
        @total_jobs = @jobs.count
      end

      def leaderboard
        @week_start, @week_end = current_shop_week
        @technicians = current_shop.technicians.order(:email)
        @tech_stats = build_tech_stats(@technicians)
      end

      private

      def current_shop_week
        today = Date.current
        monday = today - ((today.wday - 1) % 7)
        saturday = monday + 5
        [ monday, saturday ]
      end

      def current_shop_jobs_this_week
        monday, saturday = current_shop_week
        CarUs::ServiceJob
          .completed
          .joins(:technician)
          .where(technicians: { shop_id: current_shop.id })
          .where(completed_at: monday..saturday.end_of_day)
      end

      def build_service_counts(jobs, services)
        descriptions = jobs.pluck(:description).map(&:downcase)
        services.each_with_object({}) do |svc, hash|
          count = descriptions.count { |d| d.include?(svc.name.downcase) }
          hash[svc] = {
            count: count,
            hours: jobs.select { |j| j.description.downcase.include?(svc.name.downcase) }.sum(&:book_hours).to_f
          }
        end
      end

      def build_tech_stats(technicians)
        monday, saturday = current_shop_week
        technicians.map do |tech|
          jobs = tech.service_jobs.completed
            .where(completed_at: monday..saturday.end_of_day)
          target_hours = tech.effective_target_hours
          total_hours = jobs.sum(:book_hours).to_f
          pct = target_hours.positive? ? [ (total_hours / target_hours * 100).round, 100 ].min : 0

          tech_target_svcs = tech.target_services
          completed_descs = jobs.pluck(:description).map(&:downcase)
          service_list = tech_target_svcs.map do |svc_name|
            { name: svc_name, done: completed_descs.any? { |d| d.include?(svc_name.downcase) } }
          end

          {
            technician: tech,
            total_hours: total_hours,
            total_jobs: jobs.count,
            target_hours: target_hours,
            pct: pct,
            status: pct >= 100 ? "killing_it" : (pct >= 50 ? "on_track" : "behind"),
            services: service_list
          }
        end
      end
    end
  end
end
