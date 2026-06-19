class CashTransaction < ApplicationRecord
  PAYMENT_METHODS = %w[dinheiro pix debito credito].freeze
  INCOME_CATEGORIES = %w[servico produto outro].freeze
  EXPENSE_CATEGORIES = %w[aluguel material salario agua_luz outro].freeze

  belongs_to :account
  belongs_to :professional, optional: true
  belongs_to :appointment, optional: true
  belongs_to :branch, optional: true

  validates :description, presence: true
  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :date, presence: true
  validates :transaction_type, presence: true, inclusion: { in: %w[income expense] }
  validates :payment_method, inclusion: { in: PAYMENT_METHODS, allow_blank: true }

  scope :income,   -> { where(transaction_type: 'income') }
  scope :expense,  -> { where(transaction_type: 'expense') }
  scope :on_date,  ->(d) { where(date: d.beginning_of_day..d.end_of_day) }
  scope :in_range, ->(from, to) { where(date: from..to) }
  scope :for_account, ->(account_id) { where(account_id: account_id) }
end
