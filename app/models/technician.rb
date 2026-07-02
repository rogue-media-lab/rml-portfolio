class Technician < ApplicationRecord
  # CarUs technician — shop-provisioned, does NOT self-register.
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable,
         :recoverable, :rememberable, :validatable

  belongs_to :shop, class_name: "CarUs::Shop"
  has_many :conversations, class_name: "CarUs::Conversation", dependent: :destroy
  has_many :assigned_bookings, class_name: "CarUs::BookingRequest", foreign_key: :technician_id, dependent: :nullify
  has_many :service_jobs, class_name: "CarUs::ServiceJob", dependent: :destroy

  enum :role, { tech: "tech", manager: "manager" }, default: :tech

  def display_name
    email.split("@").first.titleize
  end
end
