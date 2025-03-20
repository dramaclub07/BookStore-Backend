# db/migrate/20250320083142_add_google_id_to_users.rb
class AddGoogleIdToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :google_id, :string
  end
end