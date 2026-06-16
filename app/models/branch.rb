class Branch < ApplicationRecord
  belongs_to :account
  has_many :branch_professionals, dependent: :destroy
  has_many :professionals, through: :branch_professionals
  has_many :branch_schedules, dependent: :destroy
  has_many :appointments, dependent: :nullify
  has_many :holidays, dependent: :destroy

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:name) }
end
