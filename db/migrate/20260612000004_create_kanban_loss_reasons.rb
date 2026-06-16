# frozen_string_literal: true

class CreateKanbanLossReasons < ActiveRecord::Migration[7.1]
  def change
    create_table :kanban_loss_reasons do |t|
      t.references :account, null: false, foreign_key: true, index: true
      t.string :name, null: false
      t.boolean :active, default: true, null: false
      t.integer :position, default: 0, null: false
      t.timestamps
    end

    add_index :kanban_loss_reasons, [:account_id, :name], unique: true
  end
end
