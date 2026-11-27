class AddBookmarksCountToBills < ActiveRecord::Migration[8.1]
  def change
    # Счётчик лайков: поддерживается автоматически (counter_cache на Bookmark)
    # и транслируется подписчикам страницы в реальном времени.
    add_column :bills, :bookmarks_count, :integer, default: 0, null: false

    # Заполняем счётчик для уже существующих законопроектов.
    reversible do |dir|
      dir.up do
        execute <<~SQL
          UPDATE bills
          SET bookmarks_count = (
            SELECT COUNT(*) FROM bookmarks WHERE bookmarks.bill_id = bills.id
          )
        SQL
      end
    end
  end
end
