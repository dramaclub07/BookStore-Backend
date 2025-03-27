class Createcartss < ActiveRecord::Migration[8.0]
  def change
    create_table :cartss do |t|
      t.references :user, null: false, foreign_key: true
      t.references :book, null: false, foreign_key: true
      t.integer :quantity
      t.boolean :is_deletedcls

      t.timestamps
    end
  end
end
