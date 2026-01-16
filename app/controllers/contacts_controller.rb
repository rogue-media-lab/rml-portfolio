
class ContactsController < ApplicationController
  # GET /contacts/new
  def new
    @contact = Contact.new
  end

  # POST /contacts
  def create
    @contact = Contact.new(contact_params)
    preference = params[:contact_preference]

    if preference.present?
      @contact.description = "#{@contact.description}\n\n--- Contact Preference ---\n#{preference.humanize}"
    end

    # Handle Hermit Plus waitlist checkboxes
    interests = []
    interests << "Subscribe to Substack" if params[:subscribe_substack] == "yes"
    interests << "Early access to Hermit Plus" if params[:early_access] == "yes"

    if interests.any?
      @contact.description = "#{@contact.description}\n\n--- Interests ---\n#{interests.join("\n")}"
    end

    respond_to do |format|
      if @contact.save
        format.turbo_stream { render :create, status: :created }
        format.html { redirect_to hermit_plus_landing_path, notice: "Thank you! We'll be in touch soon." }
      else
        format.turbo_stream { render :new, status: :unprocessable_entity }
        format.html { render :new, status: :unprocessable_entity }
      end
    end
  end

  private

  def contact_params
    params.require(:contact).permit(:f_name, :l_name, :email, :description)
  end
end
