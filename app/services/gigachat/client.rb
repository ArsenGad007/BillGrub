# Клиент GigaChat (Сбер): упрощение текста законопроекта нейросетью.
#
# Схема работы:
#   1. POST https://ngw.devices.sberbank.ru:9443/api/v2/oauth — обмен
#      client_id/client_secret на access_token (Basic-авторизация + RqUID).
#   2. POST https://gigachat.devices.sberbank.ru/api/v1/chat/completions —
#      запрос к модели с Bearer-токеном.
#
# Ключи берутся из config/api_keys.yml (см. api_keys.example.yml).
#
# Внимание: GigaChat использует сертификаты НУЦ Минцифры. Если не задать
# ca_file и системные сертификаты их не знают, запрос упадёт с SSL-ошибкой —
# скачайте сертификаты с https://gu-st.ru (см. api_keys.example.yml).
#
# Сеть в тестах не используется: вместо Net::HTTP подставляется
# http_post -> lambda(uri, headers, body) { {status:, body:} }.
module GigaChat
  class Client
    AUTH_URL = "https://ngw.devices.sberbank.ru:9443/api/v2/oauth".freeze
    API_URL = "https://gigachat.devices.sberbank.ru/api/v1/chat/completions".freeze

    DEFAULT_MODEL = "GigaChat".freeze
    DEFAULT_SCOPE = "GIGACHAT_API_PERS".freeze
    AUTH_OPEN_TIMEOUT = 5
    AUTH_READ_TIMEOUT = 15
    API_OPEN_TIMEOUT = 10
    API_READ_TIMEOUT = 90 # генерация ответа может занимать минуту

    attr_reader :model

    def initialize(config: ApiKeys.gigachat_config, http_post: nil)
      raise NotConfiguredError, "Ключи GigaChat не заданы — заполните config/api_keys.yml" if config[:client_id].blank? || config[:client_secret].blank?

      @client_id = config[:client_id]
      @client_secret = config[:client_secret]
      @scope = config[:scope].presence || DEFAULT_SCOPE
      @model = config[:model].presence || DEFAULT_MODEL
      @ssl_verify = config.fetch(:ssl_verify, true)
      @ca_file = config[:ca_file].presence
      @http_post = http_post
    end

    # messages: [{role:, content:}, ...] — возвращает текст ответа модели.
    def complete(messages, max_tokens: 2048, temperature: 0.4)
      payload = { model: @model, messages: messages, temperature: temperature, max_tokens: max_tokens }
      response = authorized_post(API_URL, payload.to_json,
        "Content-Type" => "application/json",
        "Accept" => "application/json",
        "Authorization" => "Bearer #{access_token}")

      content = response.dig("choices", 0, "message", "content")
      raise Error, "GigaChat вернул пустой ответ" if content.blank?

      content
    end

    private

    def access_token
      return @access_token if @access_token && @expires_at && @expires_at > Time.current + 60

      response = authorized_post(AUTH_URL, "scope=#{CGI.escape(@scope)}",
        "Content-Type" => "application/x-www-form-urlencoded",
        "Accept" => "application/json",
        "Authorization" => "Basic #{Base64.strict_encode64("#{@client_id}:#{@client_secret}")}",
        "RqUID" => SecureRandom.uuid)

      @access_token = response["access_token"].presence or raise Error, "GigaChat не вернул access_token"
      @expires_at = Time.at(response["expires_at"].to_f / 1000)
      @access_token
    end

    def authorized_post(url, body, headers)
      result = @http_post ? @http_post.call(URI.parse(url), headers, body) : perform_http(url, body, headers)
      unless result[:status] == 200
        raise Error, "GigaChat вернул HTTP #{result[:status]}: #{result[:body].to_s[0, 200]}"
      end

      JSON.parse(result[:body])
    rescue JSON::ParserError => e
      raise Error, "GigaChat вернул не JSON: #{e.message}"
    end

    def perform_http(url, body, headers)
      uri = URI.parse(url)
      http = build_http(uri, url == AUTH_URL ? AUTH_READ_TIMEOUT : API_READ_TIMEOUT)
      response = http.post("#{uri.path}#{uri.query ? "?#{uri.query}" : ''}", body, headers)
      { status: response.code.to_i, body: response.body }
    rescue Net::OpenTimeout, Net::ReadTimeout, SocketError, Errno::ECONNREFUSED, OpenSSL::SSL::SSLError => e
      raise Error, "Нет связи с GigaChat: #{e.class} (проверьте сертификаты НУЦ Минцифры — см. api_keys.example.yml)"
    end

    def build_http(uri, read_timeout)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == "https"
      http.verify_mode = @ssl_verify ? OpenSSL::SSL::VERIFY_PEER : OpenSSL::SSL::VERIFY_NONE
      http.ca_file = @ca_file if @ca_file
      http.open_timeout = url == AUTH_URL ? AUTH_OPEN_TIMEOUT : API_OPEN_TIMEOUT
      http.read_timeout = read_timeout
      http
    end
  end
end
