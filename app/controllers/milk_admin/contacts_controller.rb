
class MilkAdmin::ContactsController < ApplicationController
  before_action :authenticate_milk_admin!

  def destroy
    @contact = Contact.find(params[:id])
    @contact.destroy
    redirect_to milk_admin_messages_dashboard_path, notice: "Message was successfully deleted."
  end
end
