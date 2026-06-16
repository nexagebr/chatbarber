class AddAgentIdToProfessionals < ActiveRecord::Migration[7.0]
  def change
    add_column :professionals, :agent_id, :bigint
    add_index :professionals, :agent_id
    add_index :professionals, [:account_id, :agent_id], unique: true
  end
end
