class BillsController < ApplicationController
  # Карточка законопроекта + запись просмотра в историю.
  def show
    @bill = Bill.find(params[:id])

    ViewHistory.record!(user: current_user, bill: @bill) if user_signed_in?
  end
end
