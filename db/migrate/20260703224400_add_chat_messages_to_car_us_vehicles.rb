class AddChatMessagesToCarUsVehicles < ActiveRecord::Migration[8.0]
  def change
    add_column :car_us_vehicles, :chat_messages, :jsonb
  end
end
