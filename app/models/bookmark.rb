class Bookmark < ApplicationRecord
  belongs_to :user
  belongs_to :bill, counter_cache: true

  validates :bill_id, uniqueness: { scope: :user_id, message: "уже в лайках" }

  # Реальное время: после сохранения закладки все, кто открыл страницу
  # этого законопроекта, получают обновлённый счётчик лайков по websocket.
  after_create_commit  -> { broadcast_likes_change }
  after_destroy_commit -> { broadcast_likes_change }

  # Поставить/снять закладку
  def self.toggle!(user:, bill:)
    existing = find_by(user: user, bill: bill)
    if existing
      existing.destroy!
      false
    else
      create!(user: user, bill: bill)
      true
    end
  end

  private

  # Счётчик в связанном законопроекте обновился в этой же транзакции,
  # поэтому перечитываем запись и транслируем свежее значение.
  # Если законопроект удалён вместе с закладкой — транслировать некому.
  def broadcast_likes_change
    return unless Bill.exists?(bill_id)

    bill.reload.broadcast_likes
  end
end
