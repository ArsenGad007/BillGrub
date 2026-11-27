class BookmarksController < ApplicationController
  before_action :authenticate_user!
  before_action :set_bill

  # Поставить закладку («лайк»).
  def create
    Bookmark.create!(user: current_user, bill: @bill)
    respond_to do |format|
      format.turbo_stream { render_likes_stream }
      format.html { redirect_to bill_path(@bill), notice: "Законопроект добавлен в лайки." }
    end
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique
    redirect_to bill_path(@bill), notice: "Законопроект уже в лайках."
  end

  # Снять закладку.
  def destroy
    current_user.bookmarks.find_by(bill: @bill)&.destroy!
    respond_to do |format|
      format.turbo_stream { render_likes_stream }
      format.html { redirect_to bill_path(@bill), notice: "Законопроект убран из лайков." }
    end
  end

  private

  def set_bill
    @bill = Bill.find(params[:bill_id])
  end

  # Отвечает автору действия turbo-stream'ом: заменяет счётчик лайков и кнопку
  # внутри Turbo Frame. Остальным зрителям счётчик обновляет отдельная
  # трансляция Action Cable, которую отправляет модель Bookmark.
  def render_likes_stream
    @bill.reload # counter cache обновился в БД — перечитываем актуальное значение
    render turbo_stream: [
      turbo_stream.replace(likes_dom_id, partial: "bills/likes", locals: { bill: @bill }),
      turbo_stream.replace(like_button_dom_id, partial: "bills/like_button", locals: { bill: @bill })
    ]
  end

  def likes_dom_id
    ActionView::RecordIdentifier.dom_id(@bill, :likes)
  end

  def like_button_dom_id
    ActionView::RecordIdentifier.dom_id(@bill, :like_button)
  end
end
