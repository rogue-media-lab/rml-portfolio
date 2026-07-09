# frozen_string_literal: true

class CarUs::PartCrossReference < ApplicationRecord
  validates :oem_number, :brand, :brand_number, presence: true
  validates :brand_number, uniqueness: { scope: [ :oem_number, :brand ] }

  scope :for_oem, ->(oem) { where(oem_number: oem).order(:brand) }
  scope :by_brand, ->(brand) { where(brand: brand).order(:oem_number) }
  scope :by_category, ->(cat) { where(part_category: cat) }

  # Bulk upsert from CSV or array of hashes
  def self.bulk_upsert(rows)
    rows.each do |row|
      find_or_create_by!(
        oem_number: row[:oem_number],
        brand: row[:brand]
      ) do |ref|
        ref.brand_number = row[:brand_number]
        ref.part_category = row[:part_category]
      end
    end
  end
end
