# Приводит JSON записи поиска API Госдумы (search.json) к атрибутам модели Bill.
#
# Реальная структура записи (проверено на живом API, 27.11.2026):
#   number, name, comments, introductionDate, url, transcriptUrl,
#   lastEvent: { stage: {id, name}, phase: {id, name}, solution, date,
#                document: {name, type} }
# Карточки по номеру в API нет (bill/:number → 404), поэтому маппинг построен
# только на данных поиска. Статус определяется и по стадии, и по решению:
# отклонение видно именно в lastEvent.solution, а не в названии стадии.
module DumaApi
  module BillMapper
    module_function

    # ---------- Запись поиска (search.json) ----------

    def from_search_hit(hit)
      event = hit["lastEvent"] || {}
      stage = event["stage"] || {}
      base_attrs(hit).merge(
        stage_label: stage["name"].presence,
        stage_on: parse_date(event["date"]),
        stage_result: event["solution"].presence,
        source_url: hit["url"].presence || source_url(hit["number"])
      )
    end

    # ---------- Нормализация ----------

    # «4821-8» -> «№ 4821-8» (формат, требуемый валидацией модели Bill)
    def format_number(raw)
      digits = raw.to_s.gsub(/\s+/, "").sub(/\A№/, "")
      "№ #{digits}"
    end

    # Стадия и решение из lastEvent -> enum status модели Bill.
    # solution точнее стадии: «отклонить законопроект» случается и в первом
    # чтении (проверено на живых записях), поэтому решение проверяется первым.
    def status_for_stage(stage_label, solution = nil)
      return :rejected if solution.to_s.match?(/отклон|снят|отозва/)

      text = stage_label.to_s.downcase
      return :first_reading if text.match?(/перв\S*\s+чтени|1-е чтение|i чтение/)
      return :adopted if text.match?(/совет\S*\s+федерации|президент|опубликован|повторное рассмотрение/)

      :under_review
    end

    def parse_date(raw)
      return nil if raw.blank?

      Date.parse(raw.to_s)
    rescue ArgumentError
      nil
    end

    def source_url(number)
      return nil if number.blank?

      "https://sozd.duma.gov.ru/bill/#{number.to_s.delete('№ ')}"
    end

    private_class_method def base_attrs(raw)
      {
        number: format_number(raw["number"]),
        title: raw["name"].to_s.strip.presence,
        description: raw["comments"].to_s.strip.presence,
        registered_on: parse_date(raw["introductionDate"]),
        law_number: raw["lawNumber"].to_s.strip.presence
      }
    end
  end
end
