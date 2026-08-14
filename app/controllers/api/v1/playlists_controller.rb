# frozen_string_literal: true

# API endpoint for the Hermes agent to create playlists in Zuke.
#
# POST /api/v1/playlists
#   Authorization: Bearer <token>
#   Content-Type: application/json
#
#   {
#     "playlist": {
#       "name": "Work Mix — August 2026",
#       "description": "Curated by Hermes Agent",
#       "song_ids": [1, 2, 3, 4]
#     }
#   }
#
# Returns:
#   201 Created: { id, name, song_count, url (player link) }
#   422 Unprocessable Entity: { errors: { field: ["message"] } }
module Api
  module V1
    class PlaylistsController < BaseController
      # POST /api/v1/playlists
      def create
        playlist = Playlist.new(playlist_params)

        if playlist.save
          attach_songs!(playlist)
          render json: playlist_response(playlist), status: :created
        else
          render json: { errors: playlist.errors }, status: :unprocessable_entity
        end
      end

      private

      def attach_songs!(playlist)
        return if song_ids.blank?

        song_ids.each_with_index do |song_id, index|
          song = Song.find_by(id: song_id)
          if song.nil?
            Rails.logger.warn "API Playlist: Song ID #{song_id} not found, skipping"
            next
          end

          playlist.playlist_songs.create(song: song, position: index + 1)
        end
      end

      def playlist_response(playlist)
        {
          id: playlist.id,
          name: playlist.name,
          song_count: playlist.songs.count,
          url: "#{request.base_url}/playlists/#{playlist.id}"
        }
      end

      def playlist_params
        params.require(:playlist).permit(:name, :description)
      end

      def song_ids
        params.dig(:playlist, :song_ids) || []
      end
    end
  end
end
