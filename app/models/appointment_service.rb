class AppointmentService < ApplicationRecord
  belongs_to :appointment
  belongs_to :service, foreign_key: :barber_service_id, optional: true
  belongs_to :product, optional: true
end
