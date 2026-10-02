class CreateBills < ActiveRecord::Migration[8.1]
  def change
    create_table :bills do |t|
      t.string :title
      t.string :number
      t.text :description
      t.integer :status

      t.timestamps
    end
  end
end
