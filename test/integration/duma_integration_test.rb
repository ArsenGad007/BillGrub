require "test_helper"

# Основной функционал: импорт из API Госдумы, стадия и полный текст,
# фильтр списка по дате внесения, кнопка синхронизации.
class DumaIntegrationTest < ActionDispatch::IntegrationTest
  test "фильтр по дате внесения оставляет только попадающие законопроекты" do
    get root_path, params: { from: "2026-09-01", to: "2026-09-30" }
    assert_response :success

    # в сентябре внесены № 4821-8 (20.09) и № 4790-8 (10.09)
    assert_select ".bill", count: 2
    assert_match "Внесён 20.09.2026", response.body
    assert_no_match(/Об образовании/, response.body) # 30.08 — вне периода
  end

  test "фильтр можно сбросить и увидеть все записи" do
    get root_path
    assert_select ".bill", count: Bill.count
  end

  test "на карточке показывается стадия, дата и полный текст из Госдумы" do
    bill = bills(:under_review_bill)
    bill.update_columns(
      stage_label: "Рассмотрение в первом чтении",
      stage_on: Date.new(2026, 9, 20),
      stage_result: "Назначить ответственный комитет",
      full_text: "Полный текст закона: статья 1, статья 2.",
      document_url: "https://sozd.duma.gov.ru/download/EXAMPLE-1"
    )

    get bill_path(bill)
    assert_response :success

    assert_match "Рассмотрение в первом чтении", response.body
    assert_match "Назначить ответственный комитет", response.body
    assert_match "Полный текст закона: статья 1, статья 2.", response.body
    assert_select "a[href='https://sozd.duma.gov.ru/download/EXAMPLE-1']"
  end

  test "гость не может запускать синхронизацию" do
    post bills_sync_path
    assert_redirected_to new_user_session_path
  end

  test "синхронизация без ключа объясняет, где его ввести" do
    sign_in users(:one)

    # Стаб делаем явно: на машине разработчика config/api_keys.yml заполнен,
    # и тест должен проверять реакцию на отсутствие ключей независимо от него.
    with_stub(ApiKeys, :duma_configured?, ->(*) { false }) do
      post bills_sync_path
    end

    assert_redirected_to root_path
    follow_redirect!
    assert_match(/api_keys\.yml/, flash[:alert])
    assert_equal 4, Bill.count # в базу ничего не попало
  end

  test "синхронизация импортирует законопроекты и показывает сводку" do
    sign_in users(:one)
    stats = DumaApi::Importer::Result.new(imported: 2, updated: 1, failed: 0, texts: 1)
    fake_importer = Object.new
    fake_importer.define_singleton_method(:import!) { stats }

    with_stub(ApiKeys, :duma_configured?, ->(*) { true }) do
      with_stub(DumaApi::Importer, :new, ->(limit: nil) { fake_importer }) do
        post bills_sync_path
      end
    end

    assert_redirected_to root_path
    follow_redirect!
    assert_match(/новых: 2/, flash[:notice])
  end

  test "ошибка API Госдумы превращается в понятное сообщение" do
    sign_in users(:one)

    with_stub(ApiKeys, :duma_configured?, ->(*) { true }) do
      with_stub(DumaApi::Importer, :new, lambda { |limit: nil|
        failing = Object.new
        failing.define_singleton_method(:import!) { raise DumaApi::Error, "Нет связи с API Госдумы" }
        failing
      }) do
        post bills_sync_path
      end
    end

    assert_redirected_to root_path
    follow_redirect!
    assert_match(/Нет связи/, flash[:alert])
  end
end
