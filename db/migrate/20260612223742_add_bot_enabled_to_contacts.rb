class AddBotEnabledToContacts < ActiveRecord::Migration[7.1]
  def change
    add_column :contacts, :bot_enabled, :boolean, default: true, null: false
  end
end
