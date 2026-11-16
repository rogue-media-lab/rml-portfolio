# frozen_string_literal: true

# API endpoint for the Hermes agent to upload tracks to Zuke.
#
# POST /api/v1/songs
#   Authorization: Bearer <token>
#   Content-Type: multipart/form-data
#
#   song[title]            — required
#   song[artist_name]      — required (string, not nested attrs — simpler for API callers)
#   song[album_title]      — optional
#   song[audio_file]       — required (mp3/m4a/flac file upload)
#   song[preview_audio]    — optional (30-second cut of audio_file). The public
#                            player serves the PREVIEW and a song with none is not
#                            publicly playable, so a caller that omits this leaves
#                            the song invisible until the server cuts one
#                            (Song#schedule_preview_generation). Cut it with ffmpeg
#                            before posting; see the Maestro skill.
#   song[image]            — optional (album art / cover image)
#   song[banner_video]     — optional (short looping video)
#   song[image_credit]     — optional
#   song[image_credit_url] — optional
#   song[audio_source]     — optional (e.g. "YouTube")
#   song[additional_credits] — optional
#
# Returns:
#   201 Created: { id, title, artist, album, url (player link) }
#   422 Unprocessable Entity: { errors: { field: ["message"] } }
#   401 Unauthorized: { error: "Unauthorized" }
#
# DELETE /api/v1/songs/:id
#   Authorization: Bearer ***
#
#   Permanently removes a song and purges every file attached to it. There is no
#   undo, and no read endpoint to check the id first, so the caller owns the id it
#   sends.
#
#   This is what makes a published row fixable. The API is create-only, so a track
#   that went live with no preview or wrong credits could previously only be
#   corrected from a shell on production. Delete it, then re-POST it correctly.
#
# Returns:
#   200 OK: { id, title, artist, deleted: true, purged_files: n }
#   404 Not Found: { error: "Not found" }
#   401 Unauthorized: { error: "Unauthorized" }
module Api
  module V1
    class SongsController < BaseController
      # POST /api/v1/songs
      def create
        song = Song.new
        assign_attributes!(song)

        if song.save
          render json: song_response(song), status: :created
        else
          render json: { errors: song.errors }, status: :unprocessable_entity
        end
      end

      # DELETE /api/v1/songs/:id
      def destroy
        song = Song.find_by(id: params[:id])
        return render json: { error: "Not found" }, status: :not_found unless song

        # Read everything the response needs, and hold the attachments, before the
        # record goes — afterwards there is nothing left to read them from.
        summary = { id: song.id, title: song.title, artist: song.artist&.name }
        attachments = attached_files(song)

        # Purge the files FIRST, while the row that names them still exists. Two
        # separate constraints force this shape, and both were checked rather than
        # assumed:
        #
        # 1. Destroying a Song deletes its attachment ROWS but only ENQUEUES the
        #    blob purges (Rails 8.0.2). Production runs the :async adapter, where a
        #    queued job dies with the dyno — and a purge that never ran leaves the
        #    master in a public-read bucket, fetchable by anyone holding the URL.
        #    That is the leak the preview work existed to close.
        # 2. A blob cannot be destroyed while an attachment row still points at it.
        #    ActiveStorage::Blob#purge raises ActiveRecord::InvalidForeignKey, and
        #    returns nil as though nothing happened. So purging blob-by-blob before
        #    the record goes cannot work at all, and purging after it goes is
        #    unrecoverable: the caller's retry answers 404 with the master orphaned
        #    and no longer reachable through anything.
        #
        # Attached::One#purge is the primitive that does both, in the only workable
        # order — it destroys the attachment row, which releases the foreign key,
        # and then purges the blob. The song is still present throughout, so a purge
        # that fails leaves a request the caller can simply retry.
        #
        # Nothing is rescued. A failed purge means the master is still public, and
        # the caller must not learn that from a cheerful 200.
        attachments.each(&:purge)

        song.destroy!

        render json: summary.merge(deleted: true, purged_files: attachments.size), status: :ok
      end

      private

      # The attached-file proxies themselves, not their blobs. Purging has to go
      # through the attachment: the attachment row is what holds the foreign key to
      # the blob, and the blob cannot be destroyed until that row is gone.
      #
      # The list comes off the model rather than from an array kept here. A
      # hand-maintained list is precisely what quietly misses the attachment
      # someone adds to Song next month, and the caller has no read endpoint that
      # would ever reveal what was left behind.
      def attached_files(song)
        song.class.attachment_reflections.keys.filter_map do |name|
          attachment = song.public_send(name)
          attachment if attachment.attached?
        end
      end

      # Assign all attributes from the flattened API params to the Song model.
      # Unlike the admin controller which uses nested attributes (artist_attributes:),
      # the API accepts flat string params (artist_name, album_title) for easier
      # consumption by non-Rails clients like the Hermes agent.
      def assign_attributes!(song)
        song.title = song_params[:title]

        # Artist (find or create by name)
        if song_params[:artist_name].present?
          song.artist = Artist.find_or_create_by(name: song_params[:artist_name])
        end

        # Album (optional — find or create by title + artist)
        if song_params[:album_title].present? && song.artist.present?
          song.album = Album.find_or_create_by(title: song_params[:album_title], artist: song.artist)
        end

        # File attachments
        if song_params[:audio_file].present?
          song.audio_file.attach(song_params[:audio_file])
        end

        if song_params[:image].present?
          song.image.attach(song_params[:image])
        end

        if song_params[:banner_video].present?
          song.banner_video.attach(song_params[:banner_video])
        end

        # 30-second preview, cut client-side by the caller (ffmpeg). Optional so existing
        # callers keep working; when absent the song simply has no public preview yet.
        if song_params[:preview_audio].present?
          song.preview_audio.attach(song_params[:preview_audio])
        end

        # Metadata / credits
        song.image_credit       = song_params[:image_credit]       if song_params[:image_credit].present?
        song.image_credit_url   = song_params[:image_credit_url]   if song_params[:image_credit_url].present?
        song.image_license      = song_params[:image_license]      if song_params[:image_license].present?
        song.audio_source       = song_params[:audio_source]       if song_params[:audio_source].present?
        song.audio_license      = song_params[:audio_license]      if song_params[:audio_license].present?
        song.additional_credits = song_params[:additional_credits] if song_params[:additional_credits].present?
        song.focal_point_x      = song_params[:focal_point_x]      if song_params[:focal_point_x].present?
        song.focal_point_y      = song_params[:focal_point_y]      if song_params[:focal_point_y].present?
      end

      def song_response(song)
        {
          id: song.id,
          title: song.title,
          artist: song.artist&.name,
          album: song.album&.title,
          url: "#{request.base_url}/zuke/music"
        }
      end

      def song_params
        params.require(:song).permit(
          :title, :artist_name, :album_title,
          :audio_file, :preview_audio, :image, :banner_video,
          :image_credit, :image_credit_url, :image_license,
          :audio_source, :audio_license, :additional_credits,
          :focal_point_x, :focal_point_y
        )
      end
    end
  end
end
