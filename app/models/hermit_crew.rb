class HermitCrew < ApplicationRecord
  has_many :hermit_crew_memberships, dependent: :destroy
  has_many :hermits, through: :hermit_crew_memberships

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true
  validates :season, presence: true, numericality: { only_integer: true }

  before_validation :generate_slug, on: :create

  def to_param
    slug
  end

  private

  def generate_slug
    self.slug ||= name.to_s.downcase.gsub(/[^a-z0-9]+/, "-")
  end
end
