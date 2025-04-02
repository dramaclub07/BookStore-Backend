class CreateCarts < ActiveRecord::Migration[8.0]
  def change
    create_table :carts, force: :cascade do |t|
      t.references :user, null: false, foreign_key: true
      t.references :book, null: false, foreign_key: true
      t.integer :quantity
      t.boolean :is_deleted, default: false, null: false

      t.timestamps null: false
    end
  end
end