class Commission < ApplicationRecord
  belongs_to :account
  belongs_to :professional
  belongs_to :appointment, optional: true

  validates :amount, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :percentage, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :period, presence: true

  scope :unpaid,     -> { where(paid: false) }
  scope :paid_scope, -> { where(paid: true) }
  scope :for_period, ->(period) { where(period: period) }
  scope :for_professional, ->(pid) { where(professional_id: pid) }
end
