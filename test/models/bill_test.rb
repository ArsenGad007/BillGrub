require "test_helper"

class BillTest < ActiveSupport::TestCase
  # ===== Контекст 1: валидации и статусы =====

  test "фикстура валидна" do
    assert bills(:under_review_bill).valid?
  end

  test "без названия законопроект невалиден" do
    bill = Bill.new(number: "№ 1-1")
    assert_not bill.valid?
    assert_includes bill.errors[:title], "can't be blank"
  end

  test "номер должен быть в формате «№ 123-4»" do
    bill = Bill.new(title: "Тест", number: "4821-8")
    assert_not bill.valid?
    assert bill.errors[:number].any?
  end

  test "номер уникален" do
    dup = Bill.new(title: "Дубль", number: bills(:under_review_bill).number)
    assert_not dup.valid?
  end

  test "по умолчанию статус «на рассмотрении»" do
    assert_equal "under_review", Bill.new.status
    assert_equal "На рассмотрении", Bill.new.status_label
  end

  # ===== Контекст 2: needs_simplification? =====

  test "нужно упрощать: есть текст и нет успешных упрощений" do
    # у этого законопроекта только неудачная попытка — её можно повторить
    assert bills(:under_review_bill).needs_simplification?
  end

  test "не нужно упрощать: нет исходного текста" do
    assert_not bills(:adopted_bill).needs_simplification?
  end

  test "не нужно упрощать: уже есть готовое упрощение" do
    assert_not bills(:simplified_bill).needs_simplification?
  end

  test "не нужно упрощать: упрощение уже в работе (не дублируем запрос к нейросети)" do
    assert_not bills(:in_progress_bill).needs_simplification?
  end

  # ===== Контекст 3: заявка на упрощение и показ текста =====

  test "request_simplification! создаёт pending-запись с длиной входного текста" do
    bill = bills(:under_review_bill)

    simplification = assert_difference -> { bill.simplifications.count }, 1 do
      bill.request_simplification!(model_name: "claude-sonnet")
    end

    assert simplification.pending?
    assert_equal bill.original_text.length, simplification.input_chars
    assert_equal "claude-sonnet", simplification.model_name_used
  end

  test "request_simplification! падает, если нет исходного текста" do
    assert_raises(ArgumentError) { bills(:adopted_bill).request_simplification!(model_name: "x") }
  end

  test "display_text показывает упрощённый текст, если он есть" do
    assert_equal simplifications(:done).content, bills(:simplified_bill).display_text
  end

  test "display_text откатывается на описание, если упрощения нет" do
    bill = bills(:under_review_bill)
    assert_equal bill.description, bill.display_text
  end

  test "latest_simplification берёт самое свежее завершённое" do
    bill = bills(:simplified_bill)
    newer = bill.simplifications.create!(model_name_used: "claude-opus", input_chars: 10)
    newer.complete!("Новее")

    assert_equal newer, bill.latest_simplification
  end

  test "search ищет по подстроке в названии, описании и номере (регистр запроса не важен)" do
    assert_includes Bill.search("Персональных"), bills(:under_review_bill)
    assert_includes Bill.search("онлайн-платформ"), bills(:simplified_bill)
    assert_includes Bill.search("4755"), bills(:adopted_bill)
  end

  test "search с пустой строкой возвращает всё, а % воспринимается как символ" do
    assert_equal Bill.count, Bill.search("  ").count
    assert_empty Bill.search("%")
  end
end
