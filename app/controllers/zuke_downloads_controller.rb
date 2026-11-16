# frozen_string_literal: true

# Downloading a song's files, for a signed-in user.
#
# Playing is public; taking a copy is not. This is the session-authenticated door —
# the agent uses the token-authenticated one under api/v1. Both ask
# Song#downloadable_by?, so the rule has exactly one home.
class ZukeDownloadsController < ApplicationController
  include ZukeAuth

  before_action :authenticate_user!

  # GET /zuke/songs/:id/download[?file=master|preview|image|banner_video]
  def show
    song = Song.find_by(id: params[:id])
    return head :not_found if song.nil?

    # 403 rather than 404: the song is public, so pretending it does not exist
    # would be a lie the player itself contradicts.
    return head :forbidden unless song.downloadable_by?(current_user)

    attachment = song.downloadable_file(params[:file])
    return head :not_found if attachment.nil?

    # Streamed through Rails rather than redirecting to the storage URL. The
    # master's bucket URL is the thing the preview work deliberately stopped
    # publishing, and a redirect would hand it to the caller for the length of the
    # signed link. send_data costs a buffer; it does not leak the key.
    send_data attachment.download,
              filename: attachment.filename.to_s,
              type: attachment.content_type,
              disposition: "attachment"
  end
end
