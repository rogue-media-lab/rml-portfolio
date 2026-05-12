class LabController < ApplicationController
  def index
    @contact = Contact.new
  end
end
