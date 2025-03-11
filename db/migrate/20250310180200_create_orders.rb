class CreateOrders < ActiveRecord::Migration[6.0]
  def change
    create_table :orders do |t|
      t.references :user, null: false, foreign_key: true
      t.references :book, null: false, foreign_key: true
      t.references :address, foreign_key: true
      t.integer :quantity, null: false, default: 1
      t.decimal :price_at_purchase, null: false
      t.string :status, null: false, default: "pending"
      t.decimal :total_price, null: false
      t.datetime :deleted_at
      t.timestamps
    end
  end
end
