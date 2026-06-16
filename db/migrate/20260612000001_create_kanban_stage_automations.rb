# frozen_string_literal: true

class CreateKanbanStageAutomations < ActiveRecord::Migration[7.0]
  def change
    create_table :kanban_stage_automations do |t|
      t.references :account, null: false, foreign_key: true, index: true
      t.references :stage, null: false, foreign_key: { to_table: :kanban_stages }, index: true
      t.string :action_type, null: false
      t.jsonb :action_params, default: {}
      t.integer :delay_minutes, default: 0, null: false
      t.boolean :active, default: true, null: false
      t.integer :position, default: 0, null: false
      t.timestamps
    end
  end
end
