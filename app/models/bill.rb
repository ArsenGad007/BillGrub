class Bill < ApplicationRecord
  has_many :bookmarks, dependent: :destroy
  has_many :view_histories, dependent: :destroy
  has_many :simplifications, dependent: :destroy

  # Статусы хранятся числами в БД
  enum :status, {
    under_review: 0,   # На рассмотрении
    first_reading: 1,  # Первое чтение
    adopted: 2,        # Принят
    rejected: 3        # Отклонён
  }, default: :under_review

  STATUS_LABELS = {
    "under_review"  => "На рассмотрении",
    "first_reading" => "Первое чтение",
    "adopted"       => "Принят",
    "rejected"      => "Отклонён"
  }.freeze

  validates :title, presence: true, length: { maximum: 500 }
  validates :number, presence: true, uniqueness: true,
                     format: { with: /\A№\s?\d+-\d+\z/, message: "должен выглядеть как «№ 4821-8»" }
  validates :status, presence: true
  validates :source_url, format: { with: %r{\Ahttps?://\S+\z}, message: "должен начинаться с http:// или https://" },
                         allow_blank: true

  scope :recent, -> { order(registered_on: :desc, id: :desc) }

  # Поиск по подстроке. ESCAPE нужен, чтобы «%» и «_» из запроса искались как обычные символы.
  scope :search, lambda { |query|
    q = query.to_s.strip
    next all if q.empty?

    pattern = "%#{sanitize_sql_like(q.downcase)}%"
    where(
      "LOWER(title) LIKE :p ESCAPE '\\' OR LOWER(description) LIKE :p ESCAPE '\\' OR LOWER(number) LIKE :p ESCAPE '\\'",
      p: pattern
    )
  }

  # ---------- Бизнес-логика ----------

  def status_label
    STATUS_LABELS.fetch(status)
  end

  # Закон принят или отклонён
  def final?
    adopted? || rejected?
  end

  # Последнее упрощение (по времени завершения)
  def latest_simplification
    simplifications.completed.order(completed_at: :desc, id: :desc).first
  end

  def simplified?
    simplifications.completed.exists?
  end

  # Нужно ли запускать нейросеть
  def needs_simplification?
    return false if original_text.blank?
    return false if simplifications.pending.exists?

    !simplified?
  end

  # Создаёт запись-заявку для нейросети.
  def request_simplification!(model_name:)
    raise ArgumentError, "У законопроекта нет исходного текста" if original_text.blank?

    simplifications.create!(
      model_name_used: model_name,
      input_chars: original_text.length
    )
  end

  def display_text
    latest_simplification&.content.presence || description.to_s
  end
end
