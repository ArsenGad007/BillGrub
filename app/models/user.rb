class User < ApplicationRecord
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  has_many :bookmarks, dependent: :destroy
  has_many :bookmarked_bills, through: :bookmarks, source: :bill

  has_many :view_histories, dependent: :destroy
  has_many :history_bills, through: :view_histories, source: :bill

  # ---------- Бизнес-логика ----------

  def bookmarked?(bill)
    bookmarks.exists?(bill_id: bill.id)
  end

  # Последние просмотренные законопроекты, новые сверху
  def recent_bills(limit = 20)
    history_bills.merge(ViewHistory.latest_first).limit(limit)
  end
end
