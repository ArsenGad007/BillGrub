class Bill < ApplicationRecord
  has_many :bookmarks, dependent: :destroy
  has_many :view_histories, dependent: :destroy
end