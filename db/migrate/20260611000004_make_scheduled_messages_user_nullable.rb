# frozen_string_literal: true

class MakeScheduledMessagesUserNullable < ActiveRecord::Migration[7.1]
  def change
    change_column_null :scheduled_messages, :user_id, true
    change_column_null :scheduled_messages, :inbox_id, true
  end
end
