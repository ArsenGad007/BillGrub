# «Нейросеть», которая упрощает текст законопроекта.
#
# Сейчас это локальная заглушка: она работает без внешних ключей и сети,
# поэтому happy path можно прокликать сразу после `db:seed`.
#
# Чтобы подключить настоящую LLM, замените тело .call на HTTP-запрос
# (OpenAI / Anthropic / YandexGPT / GigaChat) и верните строку с ответом.
# Остальной код (Simplification, контроллер) менять не придётся.
module NeuralSimplifier
  MODEL_NAME = "local-simplifier-v1".freeze

  # Сколько предложений оставляем в короткой версии.
  MAX_SENTENCES = 3

  # Канцелярит, от которого можно избавиться без потери смысла.
  LEGAL_BOILERPLATE = /
    (?:настоящим\s+(?:федеральным\s+)?законом
      |в\s+порядке,\s+установленном
      |в\s+соответствии\s+с
      |установленн\w+\s+настоящим)
  /ix

  # Возвращает упрощённый текст. Падает, если текста нет.
  def self.call(text, model_name: MODEL_NAME)
    source = text.to_s.strip
    raise ArgumentError, "Пустой текст законопроекта" if source.empty?

    sentences = source.split(/(?<=[.!?])\s+/).map(&:strip).reject(&:empty?)
    shortened = sentences.first(MAX_SENTENCES).map { |sentence| simplify_sentence(sentence) }
    shortened = shortened.reject(&:empty?)
    shortened = sentences.first(MAX_SENTENCES) if shortened.empty?

    "Коротко: #{shortened.join(' ')}"
  end

  # Убирает канцелярские обороты и лишние пробелы из одного предложения.
  def self.simplify_sentence(sentence)
    sentence
      .gsub(LEGAL_BOILERPLATE, "")
      .gsub(/\s+/, " ")
      .strip
      .then { |value| value.sub(/\A[,;:]\s*/, "") }
  end
end
