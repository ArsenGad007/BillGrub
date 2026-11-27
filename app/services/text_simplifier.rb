# Упрощение текста законопроекта.
#
# Выбирает провайдера по конфигурации:
#   * заполнен config/api_keys.yml (секция gigachat) -> настоящая нейросеть GigaChat;
#   * иначе -> локальная заглушка NeuralSimplifier (работает без ключей и сети,
#     поэтому демо и тесты проходят везде).
#
# Результат в любом случае сохраняется через модель Simplification —
# контроллер и виды не знают, какой провайдер отработал.
module TextSimplifier
  SYSTEM_PROMPT = <<~PROMPT.freeze
    Ты — помощник Государственной Думы для граждан. Тебе дают текст российского
    законопроекта. Перескажи его простым языком для человека без юридического
    образования: коротко, по-русски, без канцеляризмов и без выдумок.
    Формат ответа: 3-6 коротких пунктов с новой строки, каждый отвечает на вопрос
    «что предлагается изменить и кого это коснётся». Если в тексте есть вводные
    положения и сроки вступления в силу — упомяни их отдельным пунктом.
  PROMPT

  # Длинные тексты обрезаем: у модели ограничена длина контекста.
  MAX_INPUT_CHARS = 15_000
  MAX_OUTPUT_TOKENS = 2048

  module_function

  # Имя модели для записи Simplification#model_name_used.
  def model_name
    ApiKeys.gigachat_configured? ? "GigaChat (#{ApiKeys.gigachat_config[:model]})" : NeuralSimplifier::MODEL_NAME
  end

  def call(text, client: nil)
    source = text.to_s.strip
    raise ArgumentError, "Пустой текст законопроекта" if source.empty?

    return NeuralSimplifier.call(source) unless ApiKeys.gigachat_configured?

    simplify_with_gigachat(source, client: client || GigaChat::Client.new)
  end

  def simplify_with_gigachat(source, client:)
    client.complete(
      [
        { role: "system", content: SYSTEM_PROMPT },
        { role: "user", content: user_prompt(source) }
      ],
      max_tokens: MAX_OUTPUT_TOKENS
    ).to_s.strip
  end

  def user_prompt(source)
    trimmed = source.length > MAX_INPUT_CHARS ? "#{source[0, MAX_INPUT_CHARS]}…" : source
    "Упрости текст законопроекта:\n\n#{trimmed}"
  end
end
