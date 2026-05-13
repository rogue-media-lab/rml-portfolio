# Messages Controller for Milk Admin
class MilkAdmin::MessagesController < ApplicationController
  before_action :authenticate_milk_admin!

  def dashboard
    @contacts = Contact.order(created_at: :desc)

    render layout: false if turbo_frame_request?
  end

  def show
    @contact = Contact.find(params[:id])

    render layout: false if turbo_frame_request?
  end
end
