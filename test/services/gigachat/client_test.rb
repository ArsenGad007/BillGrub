require "test_helper"

module GigaChat
  class ClientTest < ActiveSupport::TestCase
    CONFIG = {
      client_id: "test-id",
      client_secret: "test-secret",
      scope: "GIGACHAT_API_PERS",
      model: "GigaChat"
    }.freeze

    AUTH_RESPONSE = {
      access_token: "token-123",
      expires_at: 1_800_000_000_000 # далеко в будущем — токен закешируется
    }.to_json

    COMPLETION_RESPONSE = {
      choices: [ { message: { role: "assistant", content: "Суть закона в трёх пунктах" } } ]
    }.to_json

    # Фейковый транспорт: проверяет заголовки и возвращает ответы по URL.
    def fake_http_post
      lambda { |uri, headers, body|
        case uri.to_s
        when Client::AUTH_URL
          assert_equal "Basic #{Base64.strict_encode64('test-id:test-secret')}", headers["Authorization"]
          assert_not_nil headers["RqUID"]
          assert_includes body, "scope=GIGACHAT_API_PERS"
          { status: 200, body: AUTH_RESPONSE }
        when Client::API_URL
          assert_equal "Bearer token-123", headers["Authorization"]
          assert_includes body, '"model":"GigaChat"'
          { status: 200, body: COMPLETION_RESPONSE }
        else
          { status: 404, body: "" }
        end
      }
    end

    test "полный цикл: OAuth -> Bearer-токен -> ответ модели" do
      client = Client.new(config: CONFIG, http_post: fake_http_post)
      answer = client.complete([ { role: "user", content: "упрости текст" } ])

      assert_equal "Суть закона в трёх пунктах", answer
    end

    test "токен запрашивается один раз и кешируется" do
      calls = 0
      transport = lambda { |uri, _headers, _body|
        calls += 1 if uri.to_s == Client::AUTH_URL
        { status: 200, body: uri.to_s == Client::AUTH_URL ? AUTH_RESPONSE : COMPLETION_RESPONSE }
      }
      client = Client.new(config: CONFIG, http_post: transport)

      3.times { client.complete([ { role: "user", content: "ещё раз" } ]) }

      assert_equal 1, calls, "access_token должен кешироваться"
    end

    test "ошибка API превращается в понятное исключение" do
      transport = lambda { |_uri, _headers, _body| { status: 401, body: '{"message":"invalid credentials"}' } }
      client = Client.new(config: CONFIG, http_post: transport)

      error = assert_raises(GigaChat::Error) { client.complete([ { role: "user", content: "привет" } ]) }
      assert_match(/401/, error.message)
    end

    test "без ключей клиент не создаётся" do
      assert_raises(GigaChat::NotConfiguredError) do
        Client.new(config: { client_id: "", client_secret: "" })
      end
    end
  end
end
