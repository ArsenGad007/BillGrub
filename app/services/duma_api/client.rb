# Клиент API Государственной Думы (Система обеспечения законодательной
# деятельности, http://api.duma.gov.ru).
#
# Все обращения идут по адресу http://api.duma.gov.ru/api/:app_token/<метод>.json
# — токен приложения задаётся в config/api_keys.yml (см. api_keys.example.yml).
#
# Сеть в тестах не используется: вместо Net::HTTP можно подставить
# http_get -> lambda(uri) { {status:, body:} }.
module DumaApi
  class Client
    BASE_URL = "http://api.duma.gov.ru/api".freeze
    OPEN_TIMEOUT = 5
    READ_TIMEOUT = 20

    # limit: API возвращает максимум 20 записей за запрос
    MAX_PAGE_SIZE = 20

    attr_reader :token

    def initialize(token: ApiKeys.duma_token, http_get: nil)
      raise NotConfiguredError, "Токен API Госдумы не задан — заполните config/api_keys.yml" if token.blank?

      @token = token
      @http_get = http_get
    end

    # Поиск по законопроектам. from/to — диапазон даты внесения (Date или nil).
    def search_bills(page: 1, limit: MAX_PAGE_SIZE, from: nil, to: nil)
      params = { page: page, limit: [ limit, MAX_PAGE_SIZE ].min }
      params[:registration_start] = from.strftime("%Y-%m-%d") if from.respond_to?(:strftime)
      params[:registration_end] = to.strftime("%Y-%m-%d") if to.respond_to?(:strftime)

      get("bills.json", params)
    end

    # Карточка одного законопроекта (номер вида «4821-8» или «№ 4821-8»).
    def bill(number)
      get("bill/#{CGI.escape(number.to_s)}.json")
    end

    def get(path, params = {})
      uri = build_uri(path, params)
      result = fetch(uri)
      raise Error, "API Госдумы вернуло HTTP #{result[:status]} для #{path}" unless result[:status] == 200

      JSON.parse(result[:body])
    rescue JSON::ParserError => e
      raise Error, "API Госдумы вернуло не JSON для #{path}: #{e.message}"
    end

    private

    def build_uri(path, params)
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
        http.get("#{uri.path}#{uri.query ? "?#{uri.query}" : ''}")
      end
      { status: response.code.to_i, body: response.body }
    rescue Net::OpenTimeout, Net::ReadTimeout, SocketError, Errno::ECONNREFUSED => e
      raise Error, "Нет связи с API Госдумы: #{e.class}"
    end
  end
end
