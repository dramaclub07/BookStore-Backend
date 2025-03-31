class ChangeIsDeletedInCarts < ActiveRecord::Migration[8.0]
  def change
    change_column_default :carts, :is_deleted, false
    change_column_null :carts, :is_deleted, false
  end
end
