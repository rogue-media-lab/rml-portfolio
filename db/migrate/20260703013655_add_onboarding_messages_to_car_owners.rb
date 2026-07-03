class AddOnboardingMessagesToCarOwners < ActiveRecord::Migration[8.0]
  def change
    add_column :car_owners, :onboarding_messages, :jsonb
  end
end
