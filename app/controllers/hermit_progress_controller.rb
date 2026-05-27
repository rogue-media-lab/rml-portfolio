class HermitProgressController < ApplicationController
  before_action :authenticate_user!

  def update
    video = HermitVideo.find(params[:video_id])

    progress = current_user.watch_progresses.find_or_initialize_by(hermit_video: video)
    progress.assign_attributes(progress_params)
    progress.last_watched_at = Time.current

    if progress.save
      head :ok
    else
      head :unprocessable_entity
    end
  end

  private

  def progress_params
    params.require(:watch_progress).permit(:progress_seconds, :completed)
  end
end
