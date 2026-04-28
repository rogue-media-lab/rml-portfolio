class RockyController < ApplicationController
  allow_browser versions: :modern

  def chat
    respond_to do |format|
      format.html { render :chat, layout: false }
      format.turbo_stream { render :chat, formats: :html, layout: false }
    end
  end
end
