class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  has_and_belongs_to_many :songs
  has_many :chat_sessions, dependent: :destroy

  has_one :user_hermit_profile, dependent: :destroy
  has_many :favorites, dependent: :destroy
  has_many :favorite_videos, through: :favorites, source: :hermit_video
  has_many :watch_progresses, dependent: :destroy

  after_create :create_hermit_profile

  private

  def create_hermit_profile
    create_user_hermit_profile!(waitlist_status: "pending")
  end
end
