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
    if song.preview_audio.attached?
      Rails.logger.info("GeneratePreviewJob: Song ##{song.id} already has a preview; leaving it alone")
      return
    end

    unless song.audio_file.attached?
      Rails.logger.info("GeneratePreviewJob: Song ##{song.id} has no audio_file to cut")
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
end
