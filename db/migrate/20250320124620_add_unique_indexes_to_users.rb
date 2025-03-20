# db/migrate/YYYYMMDDHHMMSS_add_unique_indexes_to_users.rb
class AddUniqueIndexesToUsers < ActiveRecord::Migration[8.0]
  def change
    add_index :users, :google_id, unique: true
    add_index :users, :email, unique: true
  end
end