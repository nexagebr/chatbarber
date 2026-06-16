# frozen_string_literal: true

class KanbanLossReason < ApplicationRecord
  belongs_to :account

  validates :name, presence: true
  validates :name, uniqueness: { scope: :account_id, case_sensitive: false }

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(position: :asc, id: :asc) }
end
