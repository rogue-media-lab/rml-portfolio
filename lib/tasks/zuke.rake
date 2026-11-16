# frozen_string_literal: true

# Backfill previews for songs that only have a full track.
#
# This is a one-off task rather than a migration, because it does not change the
# schema and it shells out to ffmpeg — a migration that can fail on a missing
# binary is a migration that can leave a deploy half-applied.
#
# It runs the cut INLINE, via perform_now, not through the queue. Production's
# queue adapter is :async, so an enqueued cut would run on a thread inside the
# web dyno competing with live requests for memory. Run this on a one-off dyno
# instead (`heroku run bin/rails zuke:backfill_previews APPLY=1`) and the web
# dyno never sees the work.
#
#   bin/rails zuke:previews            # report only — always safe, runs by default
#   bin/rails zuke:backfill_previews   # report only; writes nothing
#   APPLY=1 bin/rails zuke:backfill_previews
#   APPLY=1 BATCH=25 bin/rails zuke:backfill_previews
namespace :zuke do
  desc "Report how many songs have a full track but no preview"
  task previews: :environment do
    scope = Song.where.missing(:preview_audio_attachment)

    total = Song.count
    with_master = Song.joins(:audio_file_attachment).count
    missing = scope.count
    with_preview = Song.joins(:preview_audio_attachment).count

    puts "Songs:                 #{total}"
    puts "With a full track:     #{with_master}"
    puts "With a preview:        #{with_preview}"
    puts "Missing a preview:     #{missing}"
    puts
    puts "Publicly playable now: #{with_preview} (a preview is what makes a song playable)"

    if missing.positive?
      puts
      puts "#{missing} of #{with_master} songs with a master would be invisible to the"
      puts "public player. Run with APPLY=1 to cut their previews before deploying."
    end
  end

  desc "Cut a preview for every song that has a full track but no preview (APPLY=1 to write)"
  task backfill_previews: :environment do
    batch_size = Integer(ENV.fetch("BATCH", 20))
    apply = ENV["APPLY"].to_s == "1"

    scope = Song.where.missing(:preview_audio_attachment)
                 .where.associated(:audio_file_attachment)
                 .order(:id)

    candidates = scope.count
    puts "#{candidates} song(s) have a master and no preview."

    if candidates.zero?
      puts "Nothing to do."
      next
    end

    unless apply
      puts
      puts "DRY RUN — nothing written. Pass APPLY=1 to cut previews."
      scope.limit(20).each { |song| puts "  would cut: Song ##{song.id} — #{song.title}" }
      puts "  ... and #{candidates - 20} more" if candidates > 20
      next
    end

    cut = 0
    failed = []
    processed = []

    # Batched, and re-queried each round: a song that comes back with a preview
    # drops out of the scope. `processed` is what keeps this terminating — a song
    # whose cut fails stays in the scope (it still has no preview) and would
    # otherwise be retried forever.
    loop do
      batch = Song.where.missing(:preview_audio_attachment)
                  .where.associated(:audio_file_attachment)
                  .where.not(id: processed)
                  .order(:id)
                  .limit(batch_size)
                  .to_a
      break if batch.empty?

      batch.each do |song|
        GeneratePreviewJob.perform_now(song)

        # The cut attaches a preview, and the model's after_commit callback
        # enqueues the waveform. On the :async adapter that job runs on a thread
        # that dies with this process — the last song in the run reliably lost
        # its waveform. A one-off task should not depend on the queue, so this
        # runs it inline as well; the enqueued one is idempotent.
        song.reload
        GenerateWaveformJob.perform_now(song, "preview_audio") if song.preview_audio.attached? && !song.preview_waveform_data.attached?

        song.reload

        if song.preview_audio.attached?
          cut += 1
          puts "  ok    Song ##{song.id} — #{song.title}"
        else
          failed << song.id
          puts "  FAIL  Song ##{song.id} — #{song.title}"
        end
      end

      processed.concat(batch.map(&:id))
    end

    puts
    puts "Cut #{cut} preview(s)."
    if failed.any?
      puts "#{failed.size} failed and still have no preview: #{failed.join(', ')}"
      puts "Those songs are not playable publicly until they are handled."
    end
  end
end
