class ChangeMobileNumberAndPasswordDigestToNullableInUsers < ActiveRecord::Migration[8.0]
  def change
    change_column_null :users, :mobile_number, true
    change_column_null :users, :password_digest, true
  end
end
