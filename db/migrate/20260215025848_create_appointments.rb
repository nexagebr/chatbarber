class CreateAppointments < ActiveRecord::Migration[7.1]
  def change
    create_table :appointments do |t|
      t.references :account, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.references :contact, null: false, foreign_key: true
      t.datetime :start_at
      t.datetime :end_at
      t.integer :status
      t.text :notes

      t.timestamps
    end
  end
end
