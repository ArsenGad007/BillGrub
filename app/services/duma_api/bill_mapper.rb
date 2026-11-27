# Приводит JSON ответов API Госдумы к атрибутам модели Bill.
#
# API отдаёт поля с заглавной буквы и в разных секциях (поиск отдаёт
# «lastStage», карточка — массив «stages»), поэтому маппинг намеренно
# терпим к вариантам: проверяются возможные ключи, даты — в трёх форматах.
module DumaApi
  module BillMapper
    module_function

    # ---------- Поиск (/bills.json) ----------

    def from_search_hit(hit)
      stage = hit["lastStage"] || {}
      attrs = base_attrs(hit)
      attrs.merge(
        stage_label: stage["stage"].presence || stage["name"].presence,
        stage_on: parse_date(stage["date"]),
        stage_result: stage["result"].presence,
        source_url: source_url(hit["number"])
      )
    end

    # ---------- Карточка (/bill/:number.json) ----------

    def from_card(card)
      stage = last_stage(card)
      attrs = base_attrs(card)
      # Пустая/недоступная карточка не должна затирать данные поиска
      attrs = attrs.except(:number, :title) if card["number"].blank?
      attrs.merge(
        stage_label: attrs[:stage_label].presence || stage[:label],
        stage_on: attrs[:stage_on].presence || stage[:date],
        stage_result: attrs[:stage_result].presence || stage[:result],
        document_url: document_url(card)
      )
    end

    # ---------- Нормализация ----------

    # «4821-8» -> «№ 4821-8» (формат, требуемый валидацией модели Bill)
    def format_number(raw)
      digits = raw.to_s.gsub(/\s+/, "").sub(/\A№/, "")
      "№ #{digits}"
    end

    # Стадия из API -> enum status модели Bill
    def status_for_stage(stage_label)
      text = stage_label.to_s.downcase
      return :rejected if text.match?(/отклон|снят|отозван/)
      return :adopted if text.match?(/принят|подписан|опубликов|подготовлен к подписанию/)
      return :first_reading if text.match?(/перв\S*\s+чтени|1-е чтение|I чтение/)

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
      stage = raw["lastStage"] || {}
      {
        number: format_number(raw["number"]),
        title: raw["title"].to_s.strip.presence,
        description: raw["commentTitle"].to_s.strip.presence,
        registered_on: parse_date(raw["registrationDate"] || raw["dateIntro"] || stage["date"]),
        law_number: raw["lawNumber"].to_s.strip.presence
      }
    end

    private_class_method def last_stage(card)
      stages = card["stages"].to_a
      last = stages.reject { |stage| stage["stage"].blank? && stage["name"].blank? }.last || {}
      {
        label: last["stage"].presence || last["name"].presence,
        date: parse_date(last["date"]),
        result: last["result"].presence
      }
    end

    private_class_method def document_url(card)
      texts = card["texts"].presence || card["documents"].presence || []
      first = texts.find { |doc| doc["url"].present? }
      return nil if first.nil?

      url = first["url"].to_s
      url.match?(%r{\Ahttps?://}) ? url : "https://sozd.duma.gov.ru/#{url.delete_prefix('/')}"
    end
  end
end
