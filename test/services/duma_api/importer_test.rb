require "test_helper"

module DumaApi
  class ImporterTest < ActiveSupport::TestCase
    SEARCH = File.read(Rails.root.join("test/fixtures/duma/bills_search.json"))
    CARD = File.read(Rails.root.join("test/fixtures/duma/bill_card.json")).freeze
    # Карточка для второго законопроекта: закон принят и опубликован, текстов нет
    CARD_ADOPTED = {
      "number" => "482508-8",
      "title" => "О внесении изменений в Закон «О занятости населения»",
      "stages" => [
        { "stageId" => 1, "stage" => "Внесение", "date" => "01.04.2026" },
        { "stageId" => 11, "stage" => "Опубликование закона", "date" => "2026-06-30", "result" => "Опубликован" }
      ],
      "texts" => []
    }.to_json.freeze
    RTF_SAMPLE = <<~RTF
      {\\rtf1\\ansi{\\fonttbl{\\f0 Times New Roman;}}\\f0\\fs20
      \\u1055?\\u1088?\\u1080?\\u1084?\\u1077?\\u1088? \\u1079?\\u1072?\\u1082?\\u1086?\\u1085?\\u1072? \\par
      \\u1057?\\u1090?\\u1072?\\u1090?\\u1100?\\u1103? 1. \\u1053?\\u1086?\\u1074?\\u1099?\\u1077? \\u1087?\\u1088?\\u1072?\\u1074?\\u1080?\\u1083?\\u1072?.}
    RTF

    # Фейковый транспорт: раздаёт фикстуры по URL вместо настоящей сети.
    def fake_http_get
      lambda { |uri|
        case uri.to_s
        when /bills\.json/ then { status: 200, body: SEARCH }
        when /bill\/1271570-8\.json/ then { status: 200, body: CARD }
        when /bill\/482508-8\.json/ then { status: 200, body: CARD_ADOPTED }
        when /download/ then { status: 200, body: RTF_SAMPLE }
        else { status: 404, body: "" }
        end
      }
    end

    # Импортер с фейковым транспортом: настоящий Client с тестовым токеном,
    # тот же транспорт получает и загрузчик документов (RTF/TXT).
    def importer_with(transport, limit: 2)
      client = DumaApi::Client.new(token: "test-token", http_get: transport)
      DumaApi::Importer.new(client: client, http_get: transport, limit: limit)
    end

    IMPORTED_NUMBERS = [ "№ 1271570-8", "№ 482508-8" ].freeze

    test "импорт создаёт законопроекты со стадией, датой и полным текстом" do
      stats = importer_with(fake_http_get).import!

      assert_equal 2, stats.imported
      assert_equal 0, stats.failed
      assert_equal 2, Bill.where(number: IMPORTED_NUMBERS).count

      bill = Bill.find_by!(number: "№ 1271570-8")
      assert_equal "О внесении изменений в Налоговый кодекс", bill.title
      assert_equal "Рассмотрение в первом чтении", bill.stage_label
      assert_equal Date.new(2026, 5, 2), bill.stage_on
      assert_equal "first_reading", bill.status
      assert_equal "https://sozd.duma.gov.ru/download/5F2CE828-6BF6-4BAA-9F33-9BF07D79F6D7", bill.document_url
      assert_includes bill.full_text, "Пример закона"
      assert_includes bill.full_text, "Статья 1"
      assert_equal "https://sozd.duma.gov.ru/bill/1271570-8", bill.source_url
      assert_not_nil bill.parsed_at
    end

    test "повторный импорт обновляет, а не дублирует" do
      importer = importer_with(fake_http_get)
      importer.import!
      stats = importer.import!

      assert_equal 0, stats.imported
      assert_equal 2, stats.updated
      assert_equal 2, Bill.where(number: IMPORTED_NUMBERS).count
    end

    test "принятый и опубликованный закон получает статус adopted" do
      importer_with(fake_http_get).import!

      assert Bill.find_by!(number: "№ 482508-8").adopted?
    end

    test "падение карточки не срывает импорт всего списка" do
      transport = lambda { |uri|
        if uri.to_s.include?("bill/")
          { status: 500, body: "server error" } # карточки недоступны
        else
          { status: 200, body: SEARCH }
        end
      }

      stats = importer_with(transport).import!

      assert_equal 2, stats.imported
      bill = Bill.find_by!(number: "№ 1271570-8")
      assert_equal "Рассмотрение в первом чтении", bill.stage_label # из данных поиска
      assert_nil bill.document_url
    end

    test "фильтр по датам передаётся в запрос" do
      captured = []
      transport = lambda { |uri|
        captured << uri.query
        { status: 200, body: { bills: [], count: 0 }.to_json }
      }

      importer_with(transport).import!(from: Date.new(2026, 1, 1), to: Date.new(2026, 2, 1))

      assert_includes captured.first, "registration_start=2026-01-01"
      assert_includes captured.first, "registration_end=2026-02-01"
    end
  end
end
