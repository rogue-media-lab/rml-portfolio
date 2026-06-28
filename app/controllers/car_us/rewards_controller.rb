module CarUs
  class RewardsController < BaseController
    before_action :authenticate_car_owner!

    def index
      @points_balance = 0  # TODO: implement points system
      @points_value = 0.0
      @redemptions = current_car_owner.redemptions.completed
                       .order(redeemed_at: :desc).limit(10)
    end
  end
end