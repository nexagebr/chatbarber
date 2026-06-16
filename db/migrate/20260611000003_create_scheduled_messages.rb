class CreateScheduledMessages < ActiveRecord::Migration[7.1]
  def up
    # Table already exists from a previous migration; add missing columns
    add_column :scheduled_messages, :sent_at, :datetime unless column_exists?(:scheduled_messages, :sent_at)
    add_column :scheduled_messages, :automation_rule_id, :bigint unless column_exists?(:scheduled_messages, :automation_rule_id)
    add_index :scheduled_messages, [:conversation_id, :status] unless index_exists?(:scheduled_messages, [:conversation_id, :status])
    add_index :scheduled_messages, [:scheduled_at, :status] unless index_exists?(:scheduled_messages, [:scheduled_at, :status])
  end

  def down
    remove_column :scheduled_messages, :sent_at if column_exists?(:scheduled_messages, :sent_at)
    remove_column :scheduled_messages, :automation_rule_id if column_exists?(:scheduled_messages, :automation_rule_id)
  end
end
