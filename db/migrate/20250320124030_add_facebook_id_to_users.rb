class AddFacebookIdToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :facebook_id, :string
  end
end
