# frozen_string_literal: true

class AddInboxIdToKanbanFunnels < ActiveRecord::Migration[7.0]
  def change
    add_column :kanban_funnels, :inbox_id, :bigint, null: true
    add_index :kanban_funnels, :inbox_id
  end
end
