class AddExternalIdToProducts < ActiveRecord::Migration[7.0]
  def change
    add_column :products, :external_id, :string
    add_index :products, [:account_id, :external_id], name: 'index_products_on_account_id_and_external_id'
  end
end
