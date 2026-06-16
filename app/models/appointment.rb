class Appointment < ApplicationRecord
  belongs_to :account
  belongs_to :professional, optional: true
  belongs_to :contact, optional: true
  has_many :appointment_services, dependent: :destroy
  has_many :services, through: :appointment_services, source: :service
  has_many :products, through: :appointment_services

  enum status: { scheduled: 0, in_progress: 1, completed: 2, cancelled: 3 }, _prefix: false

  scope :in_range, ->(from, to) { where(scheduled_at: from..to) }
end
