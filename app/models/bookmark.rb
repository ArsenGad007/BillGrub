class Bookmark < ApplicationRecord
  belongs_to :user
  belongs_to :bill

  validates :bill_id, uniqueness: { scope: :user_id, message: "уже в закладках" }

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
end
