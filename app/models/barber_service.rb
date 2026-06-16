class BarberService < ApplicationRecord
  belongs_to :account
  has_many :appointment_services, dependent: :destroy
  has_many :appointments, through: :appointment_services
  scope :active, -> { where(active: true) }
end
