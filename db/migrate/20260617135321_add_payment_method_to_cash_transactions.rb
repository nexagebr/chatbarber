class AddPaymentMethodToCashTransactions < ActiveRecord::Migration[7.1]
  def change
    add_column :cash_transactions, :payment_method, :string
  end
end
