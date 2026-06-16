# frozen_string_literal: true

class KanbanFunnel < ApplicationRecord
  belongs_to :account
  has_many :kanban_funnel_inboxes, dependent: :destroy
  has_many :inboxes, through: :kanban_funnel_inboxes
  has_many :kanban_stages, foreign_key: :funnel_id, dependent: :destroy
  has_many :kanban_stage_items, foreign_key: :funnel_id, dependent: :destroy

  def won_stage
    kanban_stages.won.first
  end

  def lost_stage
    kanban_stages.lost.first
  end

  validates :name, presence: true
  validates :position, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  scope :ordered, -> { order(position: :asc) }
  scope :for_account, ->(account_id) { where(account_id: account_id) }

  before_validation :set_position, on: :create

  private

  def set_position
    return if position.present?

    max = account.kanban_funnels.maximum(:position) || -1
    self.position = max + 1
  end
end
