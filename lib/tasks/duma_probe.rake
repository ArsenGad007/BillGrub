# Диагностика API Госдумы: пробует разные имена запросов и схемы авторизации
# и печатает таблицу результатов. Запуск: bin/rails duma:probe
#
# Помогает найти рабочую схему, если API отвечает ошибкой: каждая строка —
# отдельный пробный запрос с ключами из config/api_keys.yml.

require "net/http"
require "uri"

namespace :duma do
  desc "Проверить доступность API Госдумы и рабочую схему авторизации"
  task probe: :environment do
    key = ApiKeys.duma_key
    app = ApiKeys.duma_app_token
    abort "Заполните config/api_keys.yml: нужны duma.key и duma.app_token" if key.blank? || app.blank?

    base = "http://api.duma.gov.ru/api"
    probes = {
      "search.json + app_token (текущая схема)"    => "#{base}/#{key}/search.json?app_token=#{app}&limit=1",
      "search.json без app_token"                  => "#{base}/#{key}/search.json?limit=1",
      "bills.json + app_token (старое имя)"        => "#{base}/#{key}/bills.json?app_token=#{app}&limit=1",
      "stages.json + app_token (простой метод)"    => "#{base}/#{key}/stages.json?app_token=#{app}",
      "bill/1-1.json + app_token (карточка)"       => "#{base}/#{key}/bill/1-1.json?app_token=#{app}",
      "search.json, только app-ключ в пути"        => "#{base}/#{app}/search.json?limit=1",
      "search.json, app:ключ в пути"               => "#{base}/#{app}:#{key}/search.json?limit=1",
      "search.json, ключ:app в пути"               => "#{base}/#{key}:#{app}/search.json?limit=1"
    }

    puts "Пробы API Госдумы (ключи из config/api_keys.yml):"
    probes.each do |name, url|
      uri = URI.parse(url)
      response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https",
        open_timeout: 10, read_timeout: 30) do |http|
        http.get("#{uri.path}#{uri.query ? "?#{uri.query}" : ''}")
      end
      body = response.body.to_s.dup.force_encoding(Encoding::UTF_8).gsub(/\s+/, " ").strip[0, 110]
      puts format("  %-42s HTTP %-4s %s", name, response.code, body)
    rescue StandardError => e
      puts format("  %-42s ОШИБКА  %s", name, e.class)
    end
  end
end
