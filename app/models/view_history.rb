class ViewHistory < ApplicationRecord
  belongs_to :user
  belongs_to :bill

  validates :viewed_at, presence: true

  before_validation { self.viewed_at ||= Time.current }

  scope :latest_first, -> { order(viewed_at: :desc, id: :desc) }

  # Записать просмотр
  def self.record!(user:, bill:, at: Time.current)
    entry = find_or_initialize_by(user: user, bill: bill)
    entry.viewed_at = at
    entry.save!
    entry
  end
end
