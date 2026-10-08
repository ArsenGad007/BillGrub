class AddParsingFieldsToBills < ActiveRecord::Migration[8.1]
  def change
    add_column :bills, :source_url, :string
    add_column :bills, :original_text, :text
    add_column :bills, :registered_on, :date
    add_column :bills, :parsed_at, :datetime

    change_column_default :bills, :status, from: nil, to: 0
    change_column_null :bills, :status, false, 0

    add_index :bills, :number, unique: true
    add_index :bills, :status
  end
end
