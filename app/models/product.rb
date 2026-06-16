class Product < ApplicationRecord
  belongs_to :account

  validates :name, presence: true
  scope :active, -> { where(active: true) }
end
