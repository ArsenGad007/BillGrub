class SimplificationsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_bill

  # Запускает упрощение текста нейросетью (GigaChat, а без настроенных
  # ключей — локальная заглушка) и сохраняет результат.
  def create
    simplification = @bill.request_simplification!(model_name: TextSimplifier.model_name)
    text = TextSimplifier.call(@bill.original_text)
    simplification.complete!(text)

    redirect_to bill_path(@bill), notice: "Готово! Мы упростили текст законопроекта."
  rescue StandardError => e
    simplification.fail!(e.message) if simplification&.pending?
    redirect_to bill_path(@bill), alert: "Не удалось упростить текст: #{e.message}"
  end

  private

  def set_bill
    @bill = Bill.find(params[:bill_id])
  end
end
