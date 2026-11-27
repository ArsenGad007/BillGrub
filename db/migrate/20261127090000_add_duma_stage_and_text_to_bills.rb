class AddDumaStageAndTextToBills < ActiveRecord::Migration[8.1]
  def change
    # Текущая стадия рассмотрения (например, «Рассмотрение в первом чтении»)
    add_column :bills, :stage_label, :string
    # Дата последней стадии и её результат («Внесён», «Отклонён», «Принят»…)
    add_column :bills, :stage_on, :date
    add_column :bills, :stage_result, :string
    # Номер федерального закона после подписания (например, «127-ФЗ»)
    add_column :bills, :law_number, :string
    # Ссылка на официальный документ (RTF/PDF) на sozd.duma.gov.ru
    add_column :bills, :document_url, :string
    # Полный текст законопроекта, полученный из документа API
    add_column :bills, :full_text, :text

    # Фильтр списка «по дате внесения» фильтрует по registered_on
    add_index :bills, :registered_on
  end
end
