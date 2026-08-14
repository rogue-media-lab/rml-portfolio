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

      private

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
          :audio_file, :image, :banner_video,
          :image_credit, :image_credit_url, :image_license,
          :audio_source, :audio_license, :additional_credits,
          :focal_point_x, :focal_point_y
        )
      end
    end
  end
end
