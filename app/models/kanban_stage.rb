# frozen_string_literal: true

class KanbanStage < ApplicationRecord
  belongs_to :account
  belongs_to :funnel, class_name: 'KanbanFunnel', foreign_key: :funnel_id
  belongs_to :label, optional: true

  has_many :kanban_stage_automations, foreign_key: :stage_id, dependent: :destroy

  enum stage_type: { regular: 0, won: 1, lost: 2, new_lead: 3 }

  validates :name, presence: true
  validate :single_won_per_funnel, if: -> { won? }
  validate :single_lost_per_funnel, if: -> { lost? }
  validate :single_new_lead_per_funnel, if: -> { new_lead? }
  validates :position, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :color, presence: true
  validates :label_id, uniqueness: { scope: :funnel_id, allow_nil: true }

  scope :ordered, -> { order(position: :asc) }
  scope :for_account, ->(account_id) { where(account_id: account_id) }
  scope :for_funnel, ->(funnel_id) { where(funnel_id: funnel_id) }

  before_validation :set_position, on: :create

  def as_json(options = {})
    super(options).merge(
      label: label&.as_json(only: [:id, :title, :color]),
      stage_type: stage_type
    )
  end

  private

  def set_position
    return if position.present?

    max_position = funnel.kanban_stages.maximum(:position) || -1
    self.position = max_position + 1
  end

  def single_won_per_funnel
    existing = funnel.kanban_stages.won.where.not(id: id)
    errors.add(:stage_type, 'already has a won stage in this funnel') if existing.exists?
  end

  def single_lost_per_funnel
    existing = funnel.kanban_stages.lost.where.not(id: id)
    errors.add(:stage_type, 'already has a lost stage in this funnel') if existing.exists?
  end

  def single_new_lead_per_funnel
    existing = funnel.kanban_stages.new_lead.where.not(id: id)
    errors.add(:stage_type, 'already has a new_lead stage in this funnel') if existing.exists?
  end
end
