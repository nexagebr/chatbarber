# frozen_string_literal: true

class ReplaceInboxIdWithFunnelInboxes < ActiveRecord::Migration[7.0]
  def change
    remove_column :kanban_funnels, :inbox_id, :bigint

    create_table :kanban_funnel_inboxes do |t|
      t.references :kanban_funnel, null: false, foreign_key: true, index: true
      t.bigint :inbox_id, null: false
      t.timestamps
    end

    add_index :kanban_funnel_inboxes, [:kanban_funnel_id, :inbox_id], unique: true
  end
end
