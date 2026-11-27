require "test_helper"

module DumaApi
  class BillMapperTest < ActiveSupport::TestCase
    SEARCH_HIT = JSON.parse(File.read(Rails.root.join("test/fixtures/duma/bills_search.json")))["laws"].first.freeze

    test "маппинг записи поиска: номер, название, стадия, решение, ссылка" do
      attrs = BillMapper.from_search_hit(SEARCH_HIT)

      assert_equal "№ 7902-3", attrs[:number]
      assert_equal "О внесении изменения и дополнения в Федеральный конституционный закон \"О военных судах Российской Федерации\"", attrs[:title]
      assert_nil attrs[:description] # comments пуст
      assert_nil attrs[:registered_on] # introductionDate не задана (старая запись)
      assert_equal "Рассмотрение законопроекта в первом чтении", attrs[:stage_label]
      assert_equal Date.new(2013, 9, 19), attrs[:stage_on]
      assert_equal "снять законопроект с рассмотрения Государственной Думы в связи с отзывом субъектом права законодательной инициативы", attrs[:stage_result]
      assert_equal "https://sozd.duma.gov.ru/bill/7902-3", attrs[:source_url]
    end

    test "registered_on берётся из introductionDate, если она есть" do
      attrs = BillMapper.from_search_hit(SEARCH_HIT.merge("introductionDate" => "2025-02-14"))

      assert_equal Date.new(2025, 2, 14), attrs[:registered_on]
    end

    test "номер форматируется с № и без пробелов" do
      assert_equal "№ 4821-8", BillMapper.format_number("4821-8")
      assert_equal "№ 4821-8", BillMapper.format_number("№ 4821-8")
      assert_equal "№ 4821-8", BillMapper.format_number(" № 4821-8 ")
    end

    test "решение об отклонении важнее названия стадии" do
      assert_equal :rejected, BillMapper.status_for_stage("Рассмотрение законопроекта в первом чтении", "отклонить законопроект")
      assert_equal :rejected, BillMapper.status_for_stage("Рассмотрение законопроекта во втором чтении", "отклонить законопроект и снять с дальнейшего рассмотрения")
      assert_equal :rejected, BillMapper.status_for_stage("Внесение законопроекта в Государственную Думу", "снять законопроект с рассмотрения")
      assert_equal :rejected, BillMapper.status_for_stage(nil, "отозвать законопроект")
    end

    test "стадия маппится на статусы приложения" do
      # реальные названия стадий из stages.json живого API
      assert_equal :under_review, BillMapper.status_for_stage("Внесение законопроекта в Государственную Думу")
      assert_equal :under_review, BillMapper.status_for_stage("Предварительное рассмотрение законопроекта, внесенного в Государственную Думу")
      assert_equal :first_reading, BillMapper.status_for_stage("Рассмотрение законопроекта в первом чтении")
      assert_equal :under_review, BillMapper.status_for_stage("Рассмотрение законопроекта во втором чтении")
      assert_equal :adopted, BillMapper.status_for_stage("Рассмотрение закона в Совете Федерации")
      assert_equal :adopted, BillMapper.status_for_stage("Прохождение закона у Президента Российской Федерации")
      assert_equal :adopted, BillMapper.status_for_stage("Опубликование закона")
    end

    test "даты в трёх форматах распознаются" do
      assert_equal Date.new(2026, 3, 14), BillMapper.parse_date("2026-03-14")
      assert_equal Date.new(2026, 3, 14), BillMapper.parse_date("2026-03-14T10:00:00")
      assert_equal Date.new(2026, 3, 14), BillMapper.parse_date("14.03.2026")
      assert_nil BillMapper.parse_date("")
      assert_nil BillMapper.parse_date("не дата")
    end
  end
end
