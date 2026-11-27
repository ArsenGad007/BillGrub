require "test_helper"

class TextSimplifierTest < ActiveSupport::TestCase
  SAMPLE = "Статья 1. Оператор обязан хранить персональные данные в течение срока, установленного настоящим законом.".freeze

  test "без настроенных ключей работает локальная заглушка" do
    assert_not ApiKeys.gigachat_configured?, "в тестовом окружении ключи GigaChat не заданы"

    result = TextSimplifier.call(SAMPLE)

    assert_includes result, "Коротко:"
    assert_equal NeuralSimplifier::MODEL_NAME, TextSimplifier.model_name
  end

  test "с настроенными ключами используется GigaChat" do
    seen = nil
    client = Object.new
    client.define_singleton_method(:complete) do |messages, max_tokens: 0|
      seen = { role: messages.first[:role], max_tokens: max_tokens }
      "1. Вводится правило хранения данных.\n2. Сроки закреплены законом."
    end

    with_stub(ApiKeys, :gigachat_configured?, ->(*) { true }) do
      assert_equal "GigaChat (GigaChat)", TextSimplifier.model_name

      result = TextSimplifier.call(SAMPLE, client: client)
      assert_includes result, "Вводится правило"
    end

    assert_equal "system", seen[:role]
    assert_equal 2048, seen[:max_tokens]
  end

  test "длинный текст передаётся модели в обрезанном виде" do
    seen = nil
    client = Object.new
    client.define_singleton_method(:complete) do |messages, **|
      seen = messages.last[:content]
      "ответ"
    end

    with_stub(ApiKeys, :gigachat_configured?, ->(*) { true }) do
      TextSimplifier.call("а" * (TextSimplifier::MAX_INPUT_CHARS + 500), client: client)
    end

    # seen — весь промпт: префикс «Упрости текст…» + обрезанный текст с «…»
    assert seen.length < TextSimplifier::MAX_INPUT_CHARS + 100
    assert seen.end_with?("…")
  end

  test "пустой текст отклоняется до обращения к сети" do
    error = assert_raises(ArgumentError) { TextSimplifier.call("   ") }
    assert_match(/Пустой/, error.message)
  end
end
