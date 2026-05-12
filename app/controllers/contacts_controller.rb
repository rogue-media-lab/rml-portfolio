
class ContactsController < ApplicationController
  # GET /contacts/new
  def new
    @contact = Contact.new
  end

  # POST /contacts
  def create
    @contact = Contact.new(contact_params)

    respond_to do |format|
      if @contact.save
        format.turbo_stream
        format.html { redirect_to root_path, notice: "Thank you! We'll be in touch soon." }
      else
        format.turbo_stream { render :new, status: :unprocessable_entity }
        format.html { render :new, status: :unprocessable_entity }
      end
    end
  end

  private

  def contact_params
    params.require(:contact).permit(:f_name, :l_name, :email, :phone, :description)
  end
end
