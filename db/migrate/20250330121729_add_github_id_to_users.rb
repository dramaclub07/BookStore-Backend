class AddGithubIdToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :github_id, :string
    add_index :users, :github_id, unique: true
  end
end
