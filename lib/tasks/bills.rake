# Импорт законопроектов из API Госдумы.
#
# Ключ задаётся в config/api_keys.yml (duma.app_token) или переменной
# окружения DUMA_APP_TOKEN. См. документацию: http://api.duma.gov.ru/pages/dokumentatsiya
#
#   bin/rails "bills:import_duma[20]"          # последние 20 законопроектов
#   bin/rails "bills:import_duma[20,2026-01-01,2026-03-31]"
namespace :bills do
  desc "Импорт законопроектов из API Госдумы (номер, стадия, даты, полный текст)"
  task :import_duma, %i[limit from to] => :environment do |_task, args|
    limit = (args[:limit] || "20").to_i
    limit = 20 if limit <= 0
    from = parse_date(args[:from])
    to = parse_date(args[:to])

    importer = DumaApi::Importer.new(limit: limit)
    stats = importer.import!(from: from, to: to)
    puts stats.summary
  end

  def parse_date(value)
    return nil if value.blank?

    Date.parse(value)
  rescue ArgumentError
    abort("Неверная дата: #{value} (ожидается формат YYYY-MM-DD)")
  end
end
