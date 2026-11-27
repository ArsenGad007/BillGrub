# Клиент API Государственной Думы (Система обеспечения законодательной
# деятельности, http://api.duma.gov.ru).
#
# Все обращения идут по адресу (документация «Обращение к API»):
#   http://api.duma.gov.ru/api/:key/<метод>.json?app_token=:app_token&...
# :key — личный API-ключ в пути, :app_token — ключ приложения (query-параметр).
# Оба ключа задаются в config/api_keys.yml (см. api_keys.example.yml).
#
# Сеть в тестах не используется: вместо Net::HTTP можно подставить
# http_get -> lambda(uri) { {status:, body:} }.

# Zeitwerk не загружает стандартную библиотеку Ruby — подключаем явно.
require "net/http"
require "uri"
require "cgi"
require "json"

module DumaApi
  class Client
    BASE_URL = "http://api.duma.gov.ru/api".freeze
    OPEN_TIMEOUT = 5
    READ_TIMEOUT = 20

    # API игнорирует limit и всегда отдаёт по 20 записей на страницу
    MAX_PAGE_SIZE = 20

    attr_reader :token, :app_token

    def initialize(token: ApiKeys.duma_key, app_token: ApiKeys.duma_app_token, http_get: nil)
      raise NotConfiguredError, "Личный ключ API Госдумы не задан — заполните config/api_keys.yml" if token.blank?

      @token = token
      @app_token = app_token
      @http_get = http_get
    end

    # Поиск по законопроектам (запрос search.json). from/to — диапазон даты
    # внесения (Date или nil).
    def search_bills(page: 1, limit: MAX_PAGE_SIZE, from: nil, to: nil)
      params = { page: page, limit: [ limit, MAX_PAGE_SIZE ].min, sort: "date" }
      params[:registration_start] = from.strftime("%Y-%m-%d") if from.respond_to?(:strftime)
      params[:registration_end] = to.strftime("%Y-%m-%d") if to.respond_to?(:strftime)

      get("search.json", params)
    end

    def get(path, params = {})
      uri = build_uri(path, params)
      result = fetch(uri)
      unless result[:status] == 200
        hint = " — проверьте ключи в config/api_keys.yml (нужны личный ключ duma.key и ключ приложения duma.app_token)" if result[:status] == 404
        raise Error, "API Госдумы вернуло HTTP #{result[:status]} для #{path}#{hint}"
      end

      JSON.parse(result[:body])
    rescue JSON::ParserError => e
      raise Error, "API Госдумы вернуло не JSON для #{path}: #{e.message}"
    end

    private

    def build_uri(path, params)
      params = { app_token: @app_token }.merge(params) if @app_token.present?
      query = params.compact.map { |key, value| "#{CGI.escape(key.to_s)}=#{CGI.escape(value.to_s)}" }.join("&")
      url = "#{BASE_URL}/#{token}/#{path}"
      url = "#{url}?#{query}" unless query.empty?
      URI.parse(url)
    end

    def fetch(uri)
      return @http_get.call(uri) if @http_get

      perform_http(uri)
    end

    def perform_http(uri)
      response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https",
        open_timeout: OPEN_TIMEOUT, read_timeout: READ_TIMEOUT) do |http|
        http.get("#{uri.path}#{uri.query ? "?#{uri.query}" : ''}",
          "User-Agent" => "BillGrub/1.0 (учебный проект, клиент API api.duma.gov.ru)")
      end
      { status: response.code.to_i, body: response.body }
    rescue Net::OpenTimeout, Net::ReadTimeout, SocketError, Errno::ECONNREFUSED => e
      raise Error, "Нет связи с API Госдумы: #{e.class}"
    end
  end
end
