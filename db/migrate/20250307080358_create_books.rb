class CreateBooks < ActiveRecord::Migration[8.0]
  def change
    create_table :books do |t|
      t.string :book_name
      t.string :author_name
      t.decimal :book_mrp
      t.decimal :discounted_price
      t.integer :quantity
      t.text :book_details
      t.string :genre
      t.string :book_image
      t.boolean :is_deleted

      t.timestamps
    end
  end
end
