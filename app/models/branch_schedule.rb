class BranchSchedule < ApplicationRecord
  belongs_to :branch
  validates :day_of_week, inclusion: { in: 0..6 }, uniqueness: { scope: :branch_id }
end
