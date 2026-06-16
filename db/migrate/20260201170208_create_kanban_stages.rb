class CreateKanbanStages < ActiveRecord::Migration[7.1]
  def change
    create_table :kanban_stages do |t|
      t.references :account, null: false, foreign_key: true
      t.string :name, null: false
      t.integer :position, null: false, default: 0
      t.integer :label_id
      t.string :color, default: 'bg-slate-500'

      t.timestamps
    end

    add_index :kanban_stages, [:account_id, :position]
    add_index :kanban_stages, [:account_id, :label_id], unique: true, where: 'label_id IS NOT NULL'
  end
end
