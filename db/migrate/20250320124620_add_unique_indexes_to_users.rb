class AddUniqueIndexesToUsers < ActiveRecord::Migration[7.0]
  def change
    add_index :users, :email, unique: true
    add_index :users, :mobile_number, unique: true
  end
end