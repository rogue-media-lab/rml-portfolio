module CarUs
  class ServiceJobsController < CarUs::BaseController
    before_action :authenticate_technician!
    before_action :set_job, only: [ :show, :edit, :update, :destroy ]

    def create
      @vehicle = CarUs::Vehicle.find(params[:tech_lookup_id])
      @job = @vehicle.service_jobs.build(job_params)
      @job.technician = current_technician
      @job.status = "completed"

      # Auto-match hours if blank — look up labor_time by description
      if @job.book_hours.blank? && @job.description.present?
        match = CarUs::LaborTime.find_by("LOWER(service) LIKE ?", "%#{@job.description.downcase}%")
        @job.book_hours = match&.hours
      end

      if @job.save
        save_parts(@job) if params[:parts].present?
        redirect_to tech_lookup_path(@vehicle), notice: "Job logged — #{@job.book_hours}h"
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
  end
end
