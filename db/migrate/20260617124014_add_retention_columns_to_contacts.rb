class AddRetentionColumnsToContacts < ActiveRecord::Migration[7.1]
  def change
    add_column :contacts, :last_winback_sent_at, :datetime
    add_column :contacts, :last_birthday_greeting_at, :datetime
  end
end
