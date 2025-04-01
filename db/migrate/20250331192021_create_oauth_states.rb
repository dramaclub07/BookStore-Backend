class CreateOauthStates < ActiveRecord::Migration[7.0]
  def change
    create_table :oauth_states do |t|
      t.string :state
      t.datetime :expires_at

      t.timestamps
    end

    add_index :oauth_states, :state, unique: true
  end
end