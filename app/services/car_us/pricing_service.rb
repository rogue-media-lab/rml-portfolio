# Computes the full price breakdown for a booking.
# Usage:
#   calc = CarUs::PricingService.new(shop: shop, service_total: 110)
#   calc.breakdown  => { subtotal: 110, supplies_fee: 5.00, travel_fee: 25.00, tax: 8.40, total: 148.40, ... }
#
class CarUs::PricingService
  attr_reader :shop, :service_total

  def initialize(shop:, service_total:)
    @shop = shop
    @service_total = service_total.to_f
  end

  def breakdown
    supplies = shop.supplies_fee_enabled? ? shop.supplies_fee : 0
    travel   = shop.travel_fee_enabled?   ? shop.travel_fee   : 0
    pretax   = service_total + supplies + travel
    tax      = (pretax * shop.tax_rate / 100.0).round(2)

    {
      subtotal:        service_total.round(2),
      supplies_fee:    supplies.round(2),
      supplies_label:  "Shop Supplies",
      travel_fee:      travel.round(2),
      travel_label:    shop.travel_fee_label,
      tax:             tax,
      tax_rate:        shop.tax_rate,
      total:           (pretax + tax).round(2),
      has_supplies:    shop.supplies_fee_enabled? && shop.supplies_fee > 0,
      has_travel:      shop.travel_fee_enabled?   && shop.travel_fee   > 0,
      has_tax:         shop.tax_rate > 0
    }
  end

  def total
    breakdown[:total]
  end
end
