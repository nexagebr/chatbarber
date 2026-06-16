class Holiday < ApplicationRecord
  belongs_to :account
  belongs_to :branch

  validates :date, :name, presence: true
  validates :date, uniqueness: { scope: :branch_id }

  scope :on_date, ->(d) { where(date: d) }
  scope :for_branch, ->(bid) { where(branch_id: bid) }
  scope :ordered, -> { order(:date) }
end
