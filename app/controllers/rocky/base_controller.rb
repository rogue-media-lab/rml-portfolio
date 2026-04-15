# frozen_string_literal: true

module Rocky
  class BaseController < ApplicationController
    before_action :authenticate_user!
    layout "rocky"
  end
end
