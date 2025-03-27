class ChangeIsDeletedIncartss < ActiveRecord::Migration[8.0]
  def change
    change_column_default :cartss, :is_deleted, false
    change_column_null :cartss, :is_deleted, false
  end
end
