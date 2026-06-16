# frozen_string_literal: true

class KanbanStageAutomation < ApplicationRecord
  belongs_to :account
  belongs_to :stage, class_name: 'KanbanStage'

  ACTION_TYPES = %w[
    send_message
    send_scheduled_message
    add_label
    remove_label
    assign_agent
    assign_team
    update_status
    update_priority
    add_note
  ].freeze

  STATUS_OPTIONS = %w[open resolved pending snoozed].freeze
  PRIORITY_OPTIONS = %w[none low medium high urgent].freeze

  validates :action_type, presence: true, inclusion: { in: ACTION_TYPES }
  validates :delay_minutes, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(position: :asc, id: :asc) }

  def as_json(options = {})
    super(options.merge(only: %i[id stage_id account_id action_type action_params delay_minutes active position created_at]))
  end
end
