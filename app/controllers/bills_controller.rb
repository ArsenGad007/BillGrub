class BillsController < ApplicationController
  before_action :authenticate_user!, only: :sync

  # Карточка законопроекта + запись просмотра в историю.
  def show
    @bill = Bill.find(params[:id])

    ViewHistory.record!(user: current_user, bill: @bill) if user_signed_in?
  end

  # Кнопка «Загрузить из Госдумы»: импорт свежих законопроектов в базу.
  def sync
    unless ApiKeys.duma_configured?
      return redirect_to root_path,
        alert: "API Госдумы не настроен: заполните config/api_keys.yml (см. config/api_keys.example.yml)"
    end

    stats = DumaApi::Importer.new(limit: 20).import!
    redirect_to root_path, notice: "Госдума: #{stats.summary}"
  rescue DumaApi::Error => e
    redirect_to root_path, alert: "Ошибка обращения к API Госдумы: #{e.message}"
  end
end
