class CreateKanbanFunnels < ActiveRecord::Migration[7.1]
  def change
    create_table :kanban_funnels do |t|
      t.references :account, null: false, foreign_key: true
      t.string :name, null: false
      t.integer :position, null: false, default: 0
      t.timestamps
    end

    add_index :kanban_funnels, [:account_id, :position]
  end
end
