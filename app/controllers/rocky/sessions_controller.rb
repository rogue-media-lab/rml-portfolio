# frozen_string_literal: true

module Rocky
  class SessionsController < BaseController
    def create
      @session = current_user.chat_sessions.create!
      redirect_to rocky_root_path
    end

    def show
      @session = current_user.chat_sessions.find(params[:id])
      @messages = @session.chat_messages.ordered
      render "rocky/chat/index"
    end

    def destroy
      session = current_user.chat_sessions.find(params[:id])
      session.destroy
      redirect_to rocky_root_path, notice: "Session cleared."
    end
  end
end
