class ThumbnailHealthCheckJob < ApplicationJob
  queue_as :default

  def perform(season: 8)
    expired_count = 0
    refreshed_count = 0
    failed_count = 0

    HermitVideo.where(season: season).find_each do |video|
      next if video.thumbnail_url.blank?

      if YoutubeService.validate_thumbnail_url(video.thumbnail_url)
        # Thumbnail is healthy — nothing to do
        next
      end

      expired_count += 1

      if video.youtube_video_id.present?
        begin
          details = YoutubeService.video_details([video.youtube_video_id])
          info = details[video.youtube_video_id]

          if info.present? && info[:thumbnail_url].present?
            video.update!(thumbnail_url: info[:thumbnail_url])
            refreshed_count += 1
          else
            Rails.logger.warn "[ThumbnailHealthCheck] No fresh thumbnail for #{video.youtube_video_id}"
            failed_count += 1
          end
        rescue YoutubeService::Error => e
          Rails.logger.error "[ThumbnailHealthCheck] YouTube API error for #{video.youtube_video_id}: #{e.message}"
          failed_count += 1
        end
      else
        failed_count += 1
      end
    end

    Rails.logger.info "[ThumbnailHealthCheck] Season #{season} complete — expired: #{expired_count}, refreshed: #{refreshed_count}, failed: #{failed_count}"

    {
      expired: expired_count,
      refreshed: refreshed_count,
      failed: failed_count
    }
  end
end
