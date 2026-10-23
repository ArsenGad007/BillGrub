class BookmarksController < ApplicationController
  before_action :authenticate_user!
  before_action :set_bill

  # Поставить закладку («лайк»).
  def create
    Bookmark.create!(user: current_user, bill: @bill)
    redirect_to bill_path(@bill), notice: "Законопроект добавлен в закладки."
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique
    redirect_to bill_path(@bill), notice: "Законопроект уже в закладках."
  end

  # Снять закладку.
  def destroy
    current_user.bookmarks.find_by(bill: @bill)&.destroy!
    redirect_to bill_path(@bill), notice: "Законопроект убран из закладок."
  end

  private

  def set_bill
    @bill = Bill.find(params[:bill_id])
  end
end
