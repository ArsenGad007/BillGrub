# Результат работы нейросети: упрощённая версия текста законопроекта.
class Simplification < ApplicationRecord
  belongs_to :bill

  enum :state, { pending: 0, completed: 1, failed: 2 }, default: :pending

  validates :model_name_used, presence: true
  validates :input_chars, :output_chars, numericality: { greater_than_or_equal_to: 0, only_integer: true }
  validates :content, presence: true, if: :completed?
  validates :error_message, presence: true, if: :failed?

  # ---------- Бизнес-логика ----------

  # Нейросеть вернула текст
  def complete!(text)
    raise ArgumentError, "Пустой ответ нейросети" if text.to_s.strip.empty?
    raise "Упрощение уже завершено" unless pending?

    update!(
      state: :completed,
      content: text.strip,
      output_chars: text.strip.length,
      completed_at: Time.current,
      error_message: nil
    )
  end

  # Нейросеть упала / таймаут / ответ отклонён
  def fail!(message)
    raise "Упрощение уже завершено" unless pending?

    update!(state: :failed, error_message: message.to_s, completed_at: Time.current)
  end

  # Во сколько раз текст стал короче (0.25 = осталось 25% от оригинала).
  def compression_ratio
    return nil unless completed? && input_chars.positive?

    (output_chars.to_f / input_chars).round(2)
  end

  # Упрощение подозрительно - стоит проверить вручную
  def suspicious?
    ratio = compression_ratio
    return false if ratio.nil?

    ratio < 0.05 || ratio > 1.0
  end

  # Можно ли перезапустить
  def retryable?
    failed?
  end
end
