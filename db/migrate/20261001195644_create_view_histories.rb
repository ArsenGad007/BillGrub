class CreateViewHistories < ActiveRecord::Migration[8.1]
  def change
    create_table :view_histories do |t|
      t.references :user, null: false, foreign_key: true
      t.references :bill, null: false, foreign_key: true
      t.datetime :viewed_at

      t.timestamps
    end
  end
end
