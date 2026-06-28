class Technician < ApplicationRecord
  # CarUs technician — shop-provisioned, does NOT self-register.
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable,
         :recoverable, :rememberable, :validatable

  belongs_to :shop, class_name: "CarUs::Shop"
end
