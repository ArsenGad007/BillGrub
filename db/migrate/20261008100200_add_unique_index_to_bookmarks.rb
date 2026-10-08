class AddUniqueIndexToBookmarks < ActiveRecord::Migration[8.1]
  def change
    add_index :bookmarks, [ :user_id, :bill_id ], unique: true
  end
end
