class AddProductIdToAppointmentServices < ActiveRecord::Migration[7.0]
  def change
    add_column :appointment_services, :product_id, :bigint
    add_index  :appointment_services, :product_id

    # Make barber_service_id nullable so we can use product_id instead
    change_column_null :appointment_services, :barber_service_id, true

    add_foreign_key :appointment_services, :products, column: :product_id
  end
end
