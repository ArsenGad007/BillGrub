class SimplificationsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_bill

  # Запускает упрощение текста «нейросетью» и сохраняет результат.
  def create
    simplification = @bill.request_simplification!(model_name: NeuralSimplifier::MODEL_NAME)
    text = NeuralSimplifier.call(@bill.original_text, model_name: NeuralSimplifier::MODEL_NAME)
    simplification.complete!(text)

    redirect_to bill_path(@bill), notice: "Готово! Мы упростили текст законопроекта."
  rescue ArgumentError, RuntimeError => e
    simplification.fail!(e.message) if simplification&.pending?
    redirect_to bill_path(@bill), alert: "Не удалось упростить текст: #{e.message}"
  end

  private

  def set_bill
    @bill = Bill.find(params[:bill_id])
  end
end
