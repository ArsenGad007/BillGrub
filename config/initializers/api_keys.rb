# Загрузка ключей внешних API из config/api_keys.yml.
#
# Файл с ключами не хранится в git (см. .gitignore): каждый разработчик
# заполняет его локально по шаблону config/api_keys.example.yml.
# Приоритет источников: переменные окружения -> config/api_keys.yml.
#
# Использование:
#   ApiKeys.duma_key               # личный API-ключ Госдумы или nil
#   ApiKeys.duma_app_token         # ключ приложения Госдумы или nil
#   ApiKeys.duma_configured?       # true, если заданы оба ключа Госдумы
#   ApiKeys.gigachat_config        # хэш настроек GigaChat
#   ApiKeys.gigachat_configured?   # true, если client_id и client_secret заданы

Rails.application.config.x.api_keys = {}.freeze

module ApiKeys
  module_function

  def duma_key
    ENV["DUMA_KEY"].presence ||
      Rails.application.config.x.api_keys.dig(:duma, :key).presence
  end

  def duma_app_token
    ENV["DUMA_APP_TOKEN"].presence ||
      Rails.application.config.x.api_keys.dig(:duma, :app_token).presence
  end

  def duma_configured?
    duma_key.present? && duma_app_token.present?
  end

  def gigachat_config
    Rails.application.config.x.api_keys.fetch(:gigachat, {}).merge(
      client_id: ENV["GIGACHAT_CLIENT_ID"].presence ||
        Rails.application.config.x.api_keys.dig(:gigachat, :client_id).presence,
      client_secret: ENV["GIGACHAT_CLIENT_SECRET"].presence ||
        Rails.application.config.x.api_keys.dig(:gigachat, :client_secret).presence
    )
  end

  def gigachat_configured?
    config = gigachat_config
    config[:client_id].present? && config[:client_secret].present?
  end
end

rails_config = Rails.root.join("config/api_keys.yml")
if rails_config.exist?
  loaded = YAML.safe_load_file(rails_config, aliases: true) || {}
  Rails.application.config.x.api_keys =
    loaded.transform_values { |value| value.is_a?(Hash) ? value.symbolize_keys : value }.deep_symbolize_keys.freeze
end
