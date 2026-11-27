require "test_helper"

module DumaApi
  class ImporterTest < ActiveSupport::TestCase
    # Фикстура — живой ответ search.json (снят 27.11.2026), 3 реальные записи.
    SEARCH = File.read(Rails.root.join("test/fixtures/duma/bills_search.json"))

    # Фейковый транспорт: раздаёт фикстуру по URL вместо настоящей сети.
    def fake_http_get
      lambda { |uri|
        if uri.to_s.include?("search.json")
          { status: 200, body: SEARCH }
        else
          { status: 404, body: "" }
        end
      }
    end

    # Импортер с фейковым транспортом: настоящий Client с тестовым токеном.
    def importer_with(transport, limit: 2)
      client = DumaApi::Client.new(token: "test-token", http_get: transport)
      DumaApi::Importer.new(client: client, http_get: transport, limit: limit)
    end

    IMPORTED_NUMBERS = [ "№ 7902-3", "№ 7886-3" ].freeze

    test "импорт создаёт законопроекты со стадией, решением и ссылкой" do
      stats = importer_with(fake_http_get).import!

      assert_equal 2, stats.imported
      assert_equal 0, stats.failed
      assert_equal 2, Bill.where(number: IMPORTED_NUMBERS).count

      bill = Bill.find_by!(number: "№ 7902-3")
      assert_equal "О внесении изменения и дополнения в Федеральный конституционный закон \"О военных судах Российской Федерации\"", bill.title
      assert_equal "Рассмотрение законопроекта в первом чтении", bill.stage_label
      assert_equal Date.new(2013, 9, 19), bill.stage_on
      assert_equal "rejected", bill.status # решение «снять законопроект…» при стадии первого чтения
      assert_equal "https://sozd.duma.gov.ru/bill/7902-3", bill.source_url
      assert_not_nil bill.parsed_at
      assert_nil bill.description # comments пуст
      # API не отдаёт ссылку на документ — тексты не загружаются
      assert_nil bill.document_url
      assert_nil bill.full_text
    end

    test "повторный импорт обновляет, а не дублирует" do
      importer = importer_with(fake_http_get)
      importer.import!
      stats = importer.import!

      assert_equal 0, stats.imported
      assert_equal 2, stats.updated
      assert_equal 2, Bill.where(number: IMPORTED_NUMBERS).count
    end

    test "решение об отклонении переводит в rejected независимо от стадии" do
      importer_with(fake_http_get, limit: 3).import!

      # № 7886-3: стадия второго чтения, решение «отклонить законопроект…»
      assert Bill.find_by!(number: "№ 7886-3").rejected?
      assert Bill.find_by!(number: "№ 481943-6").rejected?
    end

    test "фильтр по датам передаётся в запрос" do
      captured = []
      transport = lambda { |uri|
        captured << uri.query
        { status: 200, body: { laws: [], count: 0 }.to_json }
      }

      importer_with(transport).import!(from: Date.new(2026, 1, 1), to: Date.new(2026, 2, 1))

      assert_includes captured.first, "registration_start=2026-01-01"
      assert_includes captured.first, "registration_end=2026-02-01"
    end

    test "поиск может вернуть массив записей без обёртки laws" do
      transport = lambda { |_uri|
        { status: 200, body: [ JSON.parse(SEARCH).fetch("laws").first ].to_json }
      }

      stats = importer_with(transport).import!

      assert_equal 1, stats.imported
      assert Bill.exists?(number: "№ 7902-3")
    end
  end
end
