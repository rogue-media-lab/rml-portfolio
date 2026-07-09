module CarUs
  class ServiceJobsController < CarUs::BaseController
    before_action :authenticate_technician!
    before_action :set_job, only: [ :show, :edit, :update, :destroy, :complete ]

    def create
      @vehicle = CarUs::Vehicle.find(params[:tech_lookup_id])
      @job = @vehicle.service_jobs.build(job_params)
      @job.technician = current_technician
      # Jobs default to "open" — tech completes them when the work is done

      # Auto-match hours if blank — look up labor_time by description.
      # Order by length (shortest first) so exact match wins over partial.
      if @job.book_hours.blank? && @job.description.present?
        match = CarUs::LaborTime
          .where("LOWER(service) LIKE ?", "%#{@job.description.downcase}%")
          .order(Arel.sql("LENGTH(service) ASC"))
          .first
        @job.book_hours = match&.hours
      end

      if @job.save
        save_parts(@job) if params[:parts].present?
        hrs_notice = @job.book_hours.present? ? "#{@job.book_hours}h estimated" : "hours TBD"
        redirect_to tech_lookup_path(@vehicle), notice: "Job started — #{hrs_notice}"
      else
        redirect_to tech_lookup_path(@vehicle), alert: @job.errors.full_messages.to_sentence
      end
    end

    def show
    end

    def edit
    end

    def update
      if @job.update(job_params)
        # Rebuild parts: drop old, create from params
        @job.job_parts.destroy_all
        save_parts(@job) if params[:parts].present?
        redirect_to tech_lookup_service_job_path(@job.vehicle, @job), notice: "Job updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def complete
      hours = params[:book_hours].present? ? params[:book_hours].to_f : nil
      if hours&.positive?
        @job.complete!(hours)

        # Check if shop wants auto-update and there are new parts
        notice = "Job complete — #{hours}h logged."
        if current_technician.shop&.auto_update_parts? && @job.job_parts.any?
          template = CarUs::VehicleTemplate.for_vehicle(@job.vehicle).first
          if template
            existing = CarUs::ShopPart.for_shop(current_technician.shop)
                                     .for_template(template)
                                     .pluck(:part_category)
            new_parts = @job.job_parts.reject { |p|
              cat = infer_part_category(p.name, p)
              cat.nil? || existing.include?(cat)
            }
            if new_parts.any?
              notice += " #{new_parts.size} new part(s) could be saved as shop defaults."
              redirect_to tech_lookup_path(@job.vehicle, prompt_parts: 1), notice: notice and return
            end
          end
        end

        redirect_to tech_lookup_path(@job.vehicle), notice: notice
      else
        redirect_to tech_lookup_service_job_path(@job.vehicle, @job), alert: "Hours required to complete the job."
      end
    end

    def destroy
      vehicle = @job.vehicle
      @job.destroy
      redirect_to tech_lookup_path(vehicle), notice: "Job deleted."
    end

    private

    def set_job
      @job = CarUs::ServiceJob.find(params[:id])
    end

    def job_params
      params.require(:car_us_service_job).permit(:description, :book_hours, :notes, :status)
    end

    def save_parts(job)
      params[:parts].each do |_, part|
        next if part[:name].blank?
        job.job_parts.create!(
          name: part[:name],
          quantity: part[:quantity] || 1,
          cost: part[:cost]
        )
      end
    end

    # Heuristic: guess part category from name for auto-update matching
    def infer_part_category(name, part = nil)
      return nil if name.blank?
      n = name.downcase
      return "oil_filter" if n.match?(/oil.filter|oil.filter/i) && !n.match?(/cabin|air/i)
      return "cabin_air_filter" if n.match?(/cabin/i)
      return "engine_air_filter" if n.match?(/engine.air|air.filter/i) && !n.match?(/cabin/i)
      return "spark_plug" if n.match?(/spark.plug|plug/i)
      return "oil_brand" if n.match?(/oil/i) && n.match?(/brand|synthetic|conventional|mobil|castrol|valvoline/i)
      return "coolant_brand" if n.match?(/coolant|antifreeze/i)
      return "trans_fluid_brand" if n.match?(/transmission|trans.fluid|atf|cvt/i)
      return "brake_fluid_brand" if n.match?(/brake.fluid|dot/i)
      return "wiper_blades" if n.match?(/wiper|blade/i)
      return "battery" if n.match?(/battery/i)
      return "serpentine_belt" if n.match?(/belt|serpentine/i)
      nil
    end
  end
end
