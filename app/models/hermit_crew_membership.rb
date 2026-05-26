class HermitCrewMembership < ApplicationRecord
  belongs_to :hermit_crew
  belongs_to :hermit

  validates :hermit_id, uniqueness: { scope: :hermit_crew_id }
end
