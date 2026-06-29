class CarUs::Vehicle < ApplicationRecord
  belongs_to :car_owner
  has_many :service_records, class_name: "CarUs::ServiceRecord", dependent: :destroy
  has_many :booking_requests, class_name: "CarUs::BookingRequest", dependent: :destroy
  has_many :concerns, class_name: "CarUs::Concern", dependent: :destroy

  validates :year, :make, :model, presence: true
  validates :vin, uniqueness: true, allow_nil: true, allow_blank: true
  validates :mileage, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  # NHTSA vPIC API — free, no key, cache per VIN
  def self.decode_vin(vin)
    return nil if vin.blank?

    Rails.cache.fetch("vin_decode/#{vin}", expires_in: 30.days) do
      response = Net::HTTP.get(URI("https://vpic.nhtsa.dot.gov/api/vehicles/DecodeVin/#{vin}?format=json"))
      data = JSON.parse(response)
      results = data["Results"]
      return nil unless results

      {
        year: results.find { |r| r["Variable"] == "Model Year" }&.dig("Value")&.to_i,
        make: results.find { |r| r["Variable"] == "Make" }&.dig("Value"),
        model: results.find { |r| r["Variable"] == "Model" }&.dig("Value"),
        trim: results.find { |r| r["Variable"] == "Trim" }&.dig("Value"),
        engine_size: results.find { |r| r["Variable"] == "Engine Number of Cylinders" }&.dig("Value"),
        transmission: results.find { |r| r["Variable"] == "Transmission Style" }&.dig("Value")
      }.compact
    end
  end
end
