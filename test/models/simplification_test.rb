require "test_helper"

class SimplificationTest < ActiveSupport::TestCase
  # ===== Контекст 1: complete! — нейросеть ответила =====

  test "complete! сохраняет текст, считает длину и ставит время" do
    s = simplifications(:waiting)

    travel_to Time.zone.local(2026, 10, 8, 12, 0) do
      s.complete!("  Школьные программы утвердят по новым правилам.  ")
    end

    s.reload
    assert s.completed?
    assert_equal "Школьные программы утвердят по новым правилам.", s.content
    assert_equal s.content.length, s.output_chars
    assert_equal Time.zone.local(2026, 10, 8, 12, 0), s.completed_at
  end

  test "complete! не принимает пустой ответ и остаётся pending" do
    s = simplifications(:waiting)

    assert_raises(ArgumentError) { s.complete!("   ") }
    assert s.reload.pending?
  end

  test "complete! нельзя вызвать дважды" do
    assert_raises(RuntimeError) { simplifications(:done).complete!("Ещё раз") }
  end

  # ===== Контекст 2: fail! и retryable? =====

  test "fail! помечает как неудачное и сохраняет причину" do
    s = simplifications(:waiting)
    s.fail!("Rate limit")

    assert s.reload.failed?
    assert_equal "Rate limit", s.error_message
    assert_not_nil s.completed_at
  end

  test "fail! требует текст ошибки" do
    assert_raises(ActiveRecord::RecordInvalid) { simplifications(:waiting).fail!("") }
  end

  test "retryable? только у неудачных" do
    assert simplifications(:broken).retryable?
    assert_not simplifications(:waiting).retryable?
    assert_not simplifications(:done).retryable?
  end

  # ===== Контекст 3: compression_ratio и suspicious? =====

  test "compression_ratio считает долю от исходной длины" do
    assert_equal 0.25, simplifications(:done).compression_ratio
  end

  test "compression_ratio = nil, пока результата нет" do
    assert_nil simplifications(:waiting).compression_ratio
    assert_nil simplifications(:broken).compression_ratio
  end

  test "suspicious? срабатывает на слишком короткий и слишком длинный результат" do
    s = simplifications(:done)

    assert_not s.suspicious?              # 0.25 — нормально
    s.output_chars = 10                   # 0.01 — почти пусто
    assert s.suspicious?
    s.output_chars = 1500                 # 1.5 — «упрощение» длиннее оригинала
    assert s.suspicious?
  end
end
