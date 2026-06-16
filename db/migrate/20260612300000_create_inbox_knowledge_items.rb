class CreateInboxKnowledgeItems < ActiveRecord::Migration[7.1]
  def change
    create_table :inbox_knowledge_items do |t|
      t.references :account, null: false, foreign_key: true
      t.references :inbox, null: true, foreign_key: true
      t.string :category, default: ''
      t.text :question, null: false
      t.text :answer, null: false
      t.integer :position, default: 0, null: false
      t.timestamps
    end
    add_index :inbox_knowledge_items, %i[account_id inbox_id]
  end
end
