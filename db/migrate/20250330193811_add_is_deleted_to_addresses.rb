class AddIsDeletedToAddresses < ActiveRecord::Migration[8.0]
  def change
    add_column :addresses, :is_deleted, :boolean
  end
end
