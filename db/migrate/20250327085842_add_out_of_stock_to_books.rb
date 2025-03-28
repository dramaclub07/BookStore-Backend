class AddOutOfStockToBooks < ActiveRecord::Migration[7.0]
  def change
    add_column :books, :out_of_stock, :boolean, default: false, null: false
  end
end