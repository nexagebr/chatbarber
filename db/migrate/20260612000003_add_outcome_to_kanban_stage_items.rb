# frozen_string_literal: true

class AddOutcomeToKanbanStageItems < ActiveRecord::Migration[7.1]
  def change
    add_column :kanban_stage_items, :deal_value, :decimal, precision: 15, scale: 2
    add_column :kanban_stage_items, :loss_reason, :string
    add_column :kanban_stage_items, :outcome_note, :text
    add_column :kanban_stage_items, :outcome_at, :datetime
  end
end
