class PagesController < ApplicationController
  before_action :authenticate_user!, only: %i[likes history]

  # Главная: список законопроектов из базы + поиск.
  def home
    @query = params[:q].to_s.strip
    @bills = Bill.search(@query).recent
  end

  # Закладки текущего пользователя, свежие сверху.
  def likes
    @bills = Bill.joins(:bookmarks)
                 .where(bookmarks: { user_id: current_user.id })
                 .order("bookmarks.created_at DESC")
  end

  # Ранее просмотренные законопроекты.
  def history
    @bills = current_user.recent_bills
  end
end
