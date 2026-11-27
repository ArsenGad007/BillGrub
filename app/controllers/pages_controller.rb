class PagesController < ApplicationController
  before_action :authenticate_user!, only: %i[likes history]

  # Главная: список законопроектов из базы + поиск + фильтр по дате внесения.
  def home
    @query = params[:q].to_s.strip
    @from = parse_date(params[:from])
    @to = parse_date(params[:to])

    scope = Bill.search(@query)
    scope = scope.where("registered_on >= ?", @from) if @from
    scope = scope.where("registered_on <= ?", @to) if @to
    @bills = scope.recent
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

  private

  # Строку даты из формы в Date; мусор -> nil (без фильтра).
  def parse_date(value)
    Date.parse(value.to_s)
  rescue ArgumentError, TypeError
    nil
  end
end
