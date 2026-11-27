# Импорт законопроектов из API Госдумы в базу приложения.
#
#   DumaApi::Importer.new.import!                  # по умолчанию 100 карточек
#   DumaApi::Importer.new(limit: 200).import!      # больше 200 за запуск нельзя
#
# API отдаёт ровно 20 записей на страницу (параметр limit игнорируется), поэтому
# один запуск покрывает максимум MAX_PAGES × 20 = 200 записей: больше — только
# повторными запусками. Полный текст не загружается — загрузчик DocumentFetcher
# остаётся на случай его появления. Законопроекты сопоставляются по
# уникальному номеру: новые создаются, существующие обновляются.
module DumaApi
  class Importer
    # API листается по 20 записей (Client::MAX_PAGE_SIZE), страница = page.
    MAX_PAGES = 10
    MAX_IMPORT = Client::MAX_PAGE_SIZE * MAX_PAGES
    DEFAULT_LIMIT = 100

    Result = Data.define(:imported, :updated, :failed, :texts) do
      def total
        imported + updated
      end

      def summary
        "Загружено: #{total} (новых: #{imported}, обновлено: #{updated}), " \
          "ошибок: #{failed}, текстов получено: #{texts}"
      end
    end

    attr_reader :stats

    def initialize(client: nil, http_get: nil, limit: DEFAULT_LIMIT, fetch_documents: true)
      @client = client || DumaApi::Client.new(http_get: http_get)
      @fetcher = DocumentFetcher.new(http_get: http_get)
      @limit = limit.clamp(1, MAX_IMPORT)
      @fetch_documents = fetch_documents
    end

    def import!(from: nil, to: nil)
      @stats = Result.new(imported: 0, updated: 0, failed: 0, texts: 0)
      hits = collect_hits(from:, to:)
      hits.first(@limit).each { |hit| import_bill(hit) }
      @stats
    end

    private

    def collect_hits(from:, to:)
      page = 1
      hits = []
      loop do
        response = @client.search_bills(page: page, limit: DumaApi::Client::MAX_PAGE_SIZE, from: from, to: to)
        # Ответ поиска — объект с ключом laws (живой API), либо массив записей.
        found = response.is_a?(Array) ? response : (response["laws"] || response["bills"] || response["elements"] || [])
        hits.concat(found)
        break if found.empty? || hits.size >= @limit || page >= MAX_PAGES

        page += 1
      end
      hits
    end

    def import_bill(hit)
      number = BillMapper.format_number(hit["number"])
      bill = Bill.find_or_initialize_by(number: number)
      is_new = bill.new_record?

      attrs = BillMapper.from_search_hit(hit)
      attrs[:status] = BillMapper.status_for_stage(attrs[:stage_label], attrs[:stage_result])
      attrs[:parsed_at] = Time.current

      bill.update!(attrs)
      @stats = is_new ? @stats.with(imported: @stats.imported + 1) : @stats.with(updated: @stats.updated + 1)
      import_full_text(bill)
    rescue ActiveRecord::RecordInvalid, DumaApi::Error => e
      Rails.logger.warn("[DumaApi] Пропущен законопроект #{hit['number']}: #{e.message}")
      @stats = @stats.with(failed: @stats.failed + 1)
    end

    def import_full_text(bill)
      return unless @fetch_documents
      return if bill.document_url.blank? || bill.full_text.present?

      text = @fetcher.fetch(bill.document_url)
      return if text.blank?

      bill.update!(full_text: text, original_text: bill.original_text.presence || text)
      @stats = @stats.with(texts: @stats.texts + 1)
    end
  end
end
