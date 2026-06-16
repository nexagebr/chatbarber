# frozen_string_literal: true

class CreateKanbanStageItems < ActiveRecord::Migration[7.1]
  def change
    create_table :kanban_stage_items do |t|
      t.bigint :account_id, null: false
      t.bigint :funnel_id, null: false
      t.bigint :conversation_id, null: false
      t.bigint :stage_id, null: false
      t.datetime :entered_at
      t.integer :position

      t.timestamps
    end

    add_index :kanban_stage_items, :account_id
    add_index :kanban_stage_items, :stage_id
    add_index :kanban_stage_items, %i[funnel_id conversation_id], unique: true
    add_index :kanban_stage_items, :conversation_id
  end
end
