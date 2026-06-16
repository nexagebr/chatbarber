class Service < ApplicationRecord
  self.table_name = 'barber_services'

  belongs_to :account
  has_many :appointment_services, foreign_key: :barber_service_id, dependent: :destroy
  has_many :appointments, through: :appointment_services

  scope :active, -> { where(active: true) }
end
