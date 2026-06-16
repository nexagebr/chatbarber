# frozen_string_literal: true

class KanbanStageItem < ApplicationRecord
  belongs_to :account
  belongs_to :funnel, class_name: 'KanbanFunnel', foreign_key: :funnel_id
  belongs_to :stage, class_name: 'KanbanStage', foreign_key: :stage_id
  belongs_to :conversation

  validates :funnel_id, uniqueness: { scope: :conversation_id }

  scope :for_funnel, ->(funnel_id) { where(funnel_id: funnel_id) }

  def as_json(options = {})
    super(options.merge(only: %i[id funnel_id conversation_id stage_id entered_at position]))
  end
end
