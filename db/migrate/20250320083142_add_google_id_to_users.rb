class AddIndexToUsersGoogleId < ActiveRecord::Migration[8.0]
  def change
    add_index :users, :google_id, unique: true, where: "google_id IS NOT NULL"
  end
end