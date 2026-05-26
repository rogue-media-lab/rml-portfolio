class Hermit < ApplicationRecord
  has_many :hermit_videos, dependent: :destroy
  has_many :hermit_crew_memberships, dependent: :destroy
  has_many :hermit_crews, through: :hermit_crew_memberships
  has_many :hermit_appearances, dependent: :destroy
  has_many :appeared_videos, through: :hermit_appearances, source: :hermit_video
  has_many :user_hermit_profiles, foreign_key: :favorite_hermit_id, dependent: :nullify

  has_rich_text :info
  has_one_attached :alias_image
  has_one_attached :skin_image
  has_one_attached :face_image

  validates :alias, presence: true, uniqueness: true
  validates :slug, presence: true, uniqueness: true

  before_validation :generate_slug, on: :create

  def to_param
    slug
  end

  private

  def generate_slug
    self.slug ||= self[:alias].to_s.downcase.gsub(/[^a-z0-9]+/, "-")
  end
end
