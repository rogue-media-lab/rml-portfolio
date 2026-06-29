class CarOwner < ApplicationRecord
  # CarUs consumer — vehicle owners who use the app.
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  belongs_to :shop, class_name: "CarUs::Shop", optional: true
  has_many :vehicles, class_name: "CarUs::Vehicle", dependent: :destroy
  has_many :notifications, class_name: "CarUs::Notification", dependent: :destroy
end
