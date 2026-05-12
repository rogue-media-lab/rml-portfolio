class Order < ApplicationRecord
  belongs_to :restaurant
  has_many :order_items, dependent: :destroy

  scope :pending, -> { where(status: "pending") }

  validates :customer_name, :phone, :total, presence: true

  # Broadcast new orders to the restaurant's admin channel
  after_create_commit :broadcast_new_order
  after_update_commit :broadcast_order_update

  private

  def broadcast_new_order
    broadcast_prepend_to(
      "restaurant_#{restaurant.id}_orders",
      target: "orders_list",
      partial: "milk_admin/orders/order_row",
      locals: { order: self, restaurant: restaurant }
    )

    # Also broadcast to the restaurant's orders channel for Turbo Streams
    broadcast_prepend_to(
      "restaurant_#{restaurant.id}_orders_stream",
      target: "orders_list",
      partial: "milk_admin/orders/order_row",
      locals: { order: self, restaurant: restaurant }
    )
  end

  def broadcast_order_update
    broadcast_replace_to(
      "restaurant_#{restaurant.id}_orders",
      target: "order_#{id}",
      partial: "milk_admin/orders/order_row",
      locals: { order: self, restaurant: restaurant }
    )
  end
end
