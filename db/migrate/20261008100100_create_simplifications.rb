class CreateSimplifications < ActiveRecord::Migration[8.1]
  def change
    create_table :simplifications do |t|
      t.references :bill, null: false, foreign_key: true
      t.text :content                          # упрощённый текст от нейросети
      t.string :model_name_used, null: false   # какая модель делала упрощение
      t.integer :state, null: false, default: 0 # pending / completed / failed
      t.text :error_message
      t.integer :input_chars, null: false, default: 0
      t.integer :output_chars, null: false, default: 0
      t.datetime :completed_at

      t.timestamps
    end

    add_index :simplifications, [:bill_id, :state]
  end
end
