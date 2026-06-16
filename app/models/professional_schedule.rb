class ProfessionalSchedule < ApplicationRecord
  belongs_to :professional
  validates :day_of_week, inclusion: { in: 0..6 }, uniqueness: { scope: :professional_id }
end
