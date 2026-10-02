class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  has_many :bookmarks, dependent: :destroy
  has_many :bookmarked_bills, through: :bookmarks, source: :bill

  has_many :view_histories, dependent: :destroy
  has_many :history_bills, through: :view_histories, source: :bill
end