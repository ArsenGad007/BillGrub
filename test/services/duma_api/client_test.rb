require "test_helper"

module DumaApi
  class ClientTest < ActiveSupport::TestCase
    # Контракт авторизации из документации API («Обращение к API»):
    # личный ключ — в пути, ключ приложения — в query-параметре app_token.
    test "адрес запроса: личный ключ в пути, ключ приложения в query-параметре app_token" do
      client = Client.new(token: "personal-key", app_token: "app-key-123")
      uri = client.send(:build_uri, "bills.json", { page: 1, limit: 20 })

      assert_equal "api.duma.gov.ru", uri.host
      assert_equal "/api/personal-key/bills.json", uri.path
      params = URI.decode_www_form(uri.query).to_h
      assert_equal "app-key-123", params["app_token"]
      assert_equal "1", params["page"]
      assert_equal "20", params["limit"]
    end

    test "без ключа приложения параметр app_token в запрос не попадает" do
      client = Client.new(token: "personal-key", app_token: nil)
      uri = client.send(:build_uri, "bills.json", { page: 1 })

      assert_not_includes uri.query.to_s, "app_token"
    end

    test "search_bills передаёт app_token, страницу, лимит и фильтр дат внесения" do
      captured = nil
      client = Client.new(token: "personal-key", app_token: "app-key-123",
        http_get: ->(uri) { captured = uri; { status: 200, body: '{"bills":[1]}' } })

      client.search_bills(page: 2, from: Date.new(2026, 1, 5), to: Date.new(2026, 2, 1))

      params = URI.decode_www_form(captured.query).to_h
      assert_equal "app-key-123", params["app_token"]
      assert_equal "2", params["page"]
      assert_equal "20", params["limit"]
      assert_equal "2026-01-05", params["registration_start"]
      assert_equal "2026-02-01", params["registration_end"]
    end

    test "get возвращает разобранный JSON при ответе 200" do
      client = Client.new(token: "personal-key", app_token: "app", http_get: ->(_uri) { { status: 200, body: '{"bills":[]}' } })

      assert_equal({ "bills" => [] }, client.get("bills.json"))
    end

    test "ошибка HTTP 404 содержит подсказку про ключи" do
      client = Client.new(token: "personal-key", app_token: "app", http_get: ->(_uri) { { status: 404, body: "" } })

      error = assert_raises(Error) { client.get("bills.json") }
      assert_match(/HTTP 404/, error.message)
      assert_match(/duma\.key/, error.message)
      assert_match(/duma\.app_token/, error.message)
    end

    test "не-JSON ответ превращается в понятную ошибку" do
      client = Client.new(token: "personal-key", app_token: "app", http_get: ->(_uri) { { status: 200, body: "<html>" } })

      error = assert_raises(Error) { client.get("bills.json") }
      assert_match(/не JSON/, error.message)
    end

    test "пустой личный ключ запрещает создание клиента" do
      assert_raises(NotConfiguredError) { Client.new(token: "", app_token: "app") }
    end
  end
end
