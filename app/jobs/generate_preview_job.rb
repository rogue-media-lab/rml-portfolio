# frozen_string_literal: true

# Cuts a preview server-side, for uploads that arrive without one.
#
# THIS IS THE FALLBACK PATH, NOT THE PLAN OF RECORD. Maestro holds the file and
# has ffmpeg, so it cuts before uploading — zero server CPU, zero S3 round-trips,
# and nothing to go wrong on a deploy. This job exists for the browser and
# MilkAdmin upload paths, which hand the server a full track and nothing else.
#
# Enqueued by Song#schedule_preview_generation whenever a song commits with a
# master and no preview — which is the MilkAdmin upload path, and the API path
# when a caller omits its cut. It is also what `bin/rails zuke:backfill_previews`
# runs across an existing library.
#
# Read this before relying on it:
#
#   * Production runs `:async` (config/environments/production.rb), so this runs
#     on a thread inside the web dyno, competing with live requests for its
#     memory. It is not queued behind a worker that does not exist.
#   * It downloads the full track from S3, cuts, and uploads again. That is the
#     cost the Maestro path avoids by cutting before upload.
#   * It never overwrites a preview that is already attached. An upstream cut is
#     the better cut, and re-cutting on every save would churn S3.
#
# The MilkAdmin form also accepts a preview_audio file directly, so an admin can
# supply the cut rather than making the web dyno do it.
class GeneratePreviewJob < ApplicationJob
  queue_as :default

  def perform(song)
    unless song.audio_file.attached?
      Rails.logger.info("GeneratePreviewJob: Song ##{song.id} has no audio_file to cut")
      return
    end

    discard_stale_preview(song)

    if song.preview_audio.attached?
      Rails.logger.info("GeneratePreviewJob: Song ##{song.id} already has a preview; leaving it alone")
      return
    end

    filename = song.audio_file.filename.to_s

    song.audio_file.blob.open do |source|
      result = Zuke::PreviewCutter.call(source.path, filename: filename)

      begin
        File.open(result.path) do |io|
          song.preview_audio.attach(
            io: io,
            filename: result.filename,
            content_type: result.content_type,
            # Passing duration up front means the player never has to wait on an
            # analyser job to learn how long the file is.
            metadata: { duration: result.duration }
          )
        end

        Rails.logger.info(
          "GeneratePreviewJob: Song ##{song.id} preview #{result.trimmed ? 'cut' : 'kept'} " \
          "at #{result.duration.round(2)}s#{result.normalized ? '' : ' (plain copy — loudnorm failed)'}"
        )
      ensure
        # The cutter created this directory, so the cut has to clean it up —
        # otherwise every job run orphans a /tmp/zuke-preview* tree.
        result.cleanup
      end
    end
  end

  private

  # A preview older than the master beside it describes a recording that has since
  # been replaced. Left alone, the song keeps publicly serving audio that is no
  # longer the track, and MilkAdmin has no control that removes it.
  #
  # Equal age counts as current: an upload attaches the master first and its cut
  # second, so a preview is the cut of the master it arrived with. Only a preview
  # that predates the master is stale.
  #
  # This lives in the job rather than in the model callback because it destroys
  # attachments, and doing that inside after_commit re-enters the commit chain —
  # an infinite loop that ends in a stack overflow, not a purge.
  def discard_stale_preview(song)
    return unless song.preview_audio.attached?

    master_at = song.audio_file.blob.created_at
    preview_at = song.preview_audio.blob.created_at
    return if master_at.nil? || preview_at.nil?
    return if preview_at >= master_at

    Rails.logger.info("GeneratePreviewJob: Song ##{song.id} preview predates its master; re-cutting")
    song.preview_audio.purge
    song.preview_waveform_data.purge if song.preview_waveform_data.attached?
  end
end
