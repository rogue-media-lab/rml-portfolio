class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  has_and_belongs_to_many :songs
  has_many :chat_sessions, dependent: :destroy
  has_one :rock_pet, dependent: :destroy

  # Get or create the user's RockPet virtual companion
  def rock_pet!
    rock_pet || create_rock_pet!
  end
end
