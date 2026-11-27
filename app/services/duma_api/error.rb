module DumaApi
  # Общая ошибка обращения к API Госдумы (сеть, HTTP-статус, не-JSON ответ).
  class Error < StandardError; end
end
