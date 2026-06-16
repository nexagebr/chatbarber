class AddFunnelIdToKanbanStages < ActiveRecord::Migration[7.1]
  def up
    add_column :kanban_stages, :funnel_id, :bigint

    # Create a default funnel for each valid account that already has stages
    execute <<~SQL
      INSERT INTO kanban_funnels (account_id, name, position, created_at, updated_at)
      SELECT DISTINCT ks.account_id, 'Principal', 0, NOW(), NOW()
      FROM kanban_stages ks
      INNER JOIN accounts a ON a.id = ks.account_id
    SQL

    # Assign existing stages to their account's default funnel
    execute <<~SQL
      UPDATE kanban_stages ks
      SET funnel_id = kf.id
      FROM kanban_funnels kf
      WHERE kf.account_id = ks.account_id
        AND kf.name = 'Principal'
    SQL

    # Remove orphaned stages (no valid account) that couldn't get a funnel assigned
    execute <<~SQL
      DELETE FROM kanban_stages WHERE funnel_id IS NULL
    SQL

    change_column_null :kanban_stages, :funnel_id, false
    add_foreign_key :kanban_stages, :kanban_funnels, column: :funnel_id
    add_index :kanban_stages, [:funnel_id, :position]
  end

  def down
    remove_foreign_key :kanban_stages, column: :funnel_id
    remove_index :kanban_stages, [:funnel_id, :position]
    remove_column :kanban_stages, :funnel_id
  end
end
