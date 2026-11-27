require "test_helper"

module DumaApi
  class BillMapperTest < ActiveSupport::TestCase
    SEARCH_HIT = JSON.parse(File.read(Rails.root.join("test/fixtures/duma/bills_search.json")))["bills"].first.freeze
    CARD = JSON.parse(File.read(Rails.root.join("test/fixtures/duma/bill_card.json"))).freeze

    test "маппинг записи поиска: номер, название, даты, стадия" do
      attrs = BillMapper.from_search_hit(SEARCH_HIT)

      assert_equal "№ 1271570-8", attrs[:number]
      assert_equal "О внесении изменений в Налоговый кодекс", attrs[:title]
      assert_equal "О налоговых вычетах для семей с детьми", attrs[:description]
      assert_equal Date.new(2026, 3, 14), attrs[:registered_on]
      assert_equal "Рассмотрение в первом чтении", attrs[:stage_label]
      assert_equal Date.new(2026, 5, 2), attrs[:stage_on]
      assert_equal "Назначить ответственный комитет", attrs[:stage_result]
      assert_equal "https://sozd.duma.gov.ru/bill/1271570-8", attrs[:source_url]
    end

    test "маппинг карточки: стадия берётся из истории, документ — из текстов" do
      attrs = BillMapper.from_card(CARD)

      assert_equal "Рассмотрение в первом чтении", attrs[:stage_label]
      assert_equal "Ответственный комитет назначен", attrs[:stage_result]
      assert_equal "https://sozd.duma.gov.ru/download/5F2CE828-6BF6-4BAA-9F33-9BF07D79F6D7", attrs[:document_url]
    end

    test "номер форматируется с № и без пробелов" do
      assert_equal "№ 4821-8", BillMapper.format_number("4821-8")
      assert_equal "№ 4821-8", BillMapper.format_number("№ 4821-8")
      assert_equal "№ 4821-8", BillMapper.format_number(" № 4821-8 ")
    end

    test "стадия маппится на статусы приложения" do
      assert_equal :under_review, BillMapper.status_for_stage("Предварительное рассмотрение")
      assert_equal :first_reading, BillMapper.status_for_stage("Рассмотрение в первом чтении")
      assert_equal :rejected, BillMapper.status_for_stage("Законопроект отклонён")
      assert_equal :adopted, BillMapper.status_for_stage("Опубликование закона")
    end

    test "даты в трёх форматах распознаются" do
      assert_equal Date.new(2026, 3, 14), BillMapper.parse_date("2026-03-14")
      assert_equal Date.new(2026, 3, 14), BillMapper.parse_date("2026-03-14T10:00:00")
      assert_equal Date.new(2026, 3, 14), BillMapper.parse_date("14.03.2026")
      assert_nil BillMapper.parse_date("")
      assert_nil BillMapper.parse_date("не дата")
    end

    test "относительная ссылка на документ дополняется адресом портала" do
      card = CARD.merge("texts" => [ { "url" => "/download/ABC-1" } ])

      assert_equal "https://sozd.duma.gov.ru/download/ABC-1", BillMapper.from_card(card)[:document_url]
    end
  end
end
