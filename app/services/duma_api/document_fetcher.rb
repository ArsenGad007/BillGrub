# Скачивает документ законопроекта и извлекает из него текст.
#
# API Госдумы отдаёт документы в RTF и PDF (ссылки вида
# https://sozd.duma.gov.ru/download/...). Извлечь текст без внешних
# зависимостей можно из TXT и RTF (см. DumaApi::RtfText); для PDF
# остаётся только ссылка на официальный документ.

# Zeitwerk не загружает стандартную библиотеку Ruby — подключаем явно.
require "net/http"
require "uri"

module DumaApi
  class DocumentFetcher
    OPEN_TIMEOUT = 5
    READ_TIMEOUT = 30
    MAX_BYTES = 8.megabytes

    def initialize(http_get: nil)
      @http_get = http_get
    end

    # Возвращает текст документа или nil, если формат не поддерживается.
    # Ссылки sozd.duma.gov.ru/download/<GUID> обычно без расширения — это RTF.
    def fetch(url)
      return nil if url.blank?

      case url.downcase
      when /\.txt\z/
        RtfText.cleanup(downloaded_body(url).to_s)
      when /\.pdf\z/
        nil # текст из PDF без внешних библиотек не извлечь — остаётся ссылка
      else
        RtfText.extract(downloaded_body(url).to_s).presence
      end
    end

    private

    def downloaded_body(url)
      uri = URI.parse(url)
      result = @http_get ? @http_get.call(uri) : perform_http(uri)
      result[:status] == 200 ? result[:body].to_s : ""
    rescue URI::InvalidURIError
      ""
    end

    def perform_http(uri)
      response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https",
        open_timeout: OPEN_TIMEOUT, read_timeout: READ_TIMEOUT) do |http|
        http.get("#{uri.path}#{uri.query ? "?#{uri.query}" : ''}")
      end
      { status: response.code.to_i, body: response.body.byteslice(0, MAX_BYTES).to_s }
    rescue Net::OpenTimeout, Net::ReadTimeout, SocketError, Errno::ECONNREFUSED
      { status: 0, body: "" }
    end
  end
end
